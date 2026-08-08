local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
_G.DiceIsMobile = true
_G.DiceCursedResetRemote = _G.DiceCursedResetRemote or nil
_G.DiceCursedResetGuid = _G.DiceCursedResetGuid or "f888ee6e-c86d-46e1-93d7-0639d6635d42"
pcall(function()
if not _G.DiceCursedResetHooked and hookfunction and newcclosure then
_G.DiceCursedResetHooked = true
local oldFire
oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
if not _G.DiceCursedResetRemote and typeof(self) == "Instance" and self:IsA("RemoteEvent") and self.Name:sub(1,3) == "RE/" then
_G.DiceCursedResetRemote = self
end
return oldFire(self, ...)
end))
end
end)
function _G.DiceCursedInstaReset()
if not _G.DiceCursedResetRemote then
for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
if desc:IsA("RemoteEvent") and desc.Name:sub(1,3) == "RE/" then
_G.DiceCursedResetRemote = desc
break
end
end
end
if not _G.DiceCursedResetRemote then return end
local character = LP.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if humanoid and humanoid.Health <= 0 then
pcall(function() _G.DiceCursedResetRemote:FireServer(_G.DiceCursedResetGuid, LP, "balloon") end)
return
end
local resetDetected = false
local resetConns = {}
if humanoid then
table.insert(resetConns, humanoid.Died:Connect(function() resetDetected = true end))
table.insert(resetConns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
if humanoid.Health <= 0 then resetDetected = true end
end))
end
if character then
table.insert(resetConns, character.AncestryChanged:Connect(function(_, parent)
if not parent then resetDetected = true end
end))
end
task.spawn(function()
for _ = 1, 10 do
if resetDetected then break end
pcall(function() _G.DiceCursedResetRemote:FireServer(_G.DiceCursedResetGuid, LP, "balloon") end)
task.wait(0.05)
end
for _, conn in ipairs(resetConns) do pcall(function() conn:Disconnect() end) end
end)
end
function cursedInstaReset()
return _G.DiceCursedInstaReset()
end
for _, name in ipairs({"DiceDuelsAdaptReconstruct", "AdaptHubPolished", "CyberHub"}) do
local old = PlayerGui:FindFirstChild(name)
if old then old:Destroy() end
end
local NS = 59.5
local CS = 28.8
local LAGGER_SPEED = 29
local LAGGER_CARRY_SPEED = 15
local currentSpeedMode = "Normal"
-- With WalkSpeed pinned at 16 the humanoid's ground controller spends
-- every physics step dragging you back toward 16, so a 55 set on the
-- assembly is measured at roughly 51 by the time the frame is drawn —
-- and the same shortfall shows on carry speed. Handing the humanoid the
-- figure it is meant to be walking at makes it push with the movement
-- instead of against it, and the number lands where it was set.
diceMatchWalkSpeed = diceMatchWalkSpeed ~= false
MOVE_KEYS = {
[Enum.KeyCode.W] = true,
[Enum.KeyCode.A] = true,
[Enum.KeyCode.S] = true,
[Enum.KeyCode.D] = true,
[Enum.KeyCode.Up] = true,
[Enum.KeyCode.Left] = true,
[Enum.KeyCode.Down] = true,
[Enum.KeyCode.Right] = true,
}
autoCarrySpeedEnabled = false
setAutoCarrySpeedVisual = nil
_G.DiceAutoCarryWasCarrying = false
_G.DiceAutoCarrySavedMode = nil
local autoStealEnabled = false
local selectedStealMode = "Normal"
local autoStealRadius = 62
_G.DiceStealRadii = _G.DiceStealRadii or {Normal = 62, Semi = 9}
local autoStealRadiusBox = nil
local selectedAimbotMode = "Normal"
local AIMBOT_SPEED = 58
local LAGGER_AIMBOT_SPEED = 40
_G.DiceAntiBypassAimbotSpeed = _G.DiceAntiBypassAimbotSpeed or 58
if _G.DiceAntiBypassLaggerAimbotSpeed == nil or tonumber(_G.DiceAntiBypassLaggerAimbotSpeed) == 58 then _G.DiceAntiBypassLaggerAimbotSpeed = 40 end
local autoSwingEnabled = false
local mirrorTPDownEnabled = false
_G.DiceNormalAimbotOn = _G.DiceNormalAimbotOn or false
_G.DiceAntiBypassAimbotOn = _G.DiceAntiBypassAimbotOn or false
local antiDesyncAutoSwingEnabled = false
_G.DiceAntiDesyncAimbotOn = _G.DiceAntiDesyncAimbotOn or false
local ANTI_DESYNC_AIMBOT_SPEED = 58
local batCounterEnabled = false
local medCounterEnabled = false
local antiKickEnabled = false
local setSafeModeVisual = nil
local autoResetOnMedEnabled = false
local espEnabled = false
local showTracerEnabled = false
local ragdollCountdownEnabled = false
local fpsBoostEnabled = false
local antiLagVisualEnabled = false
local nukeOptimiserEnabled = false
local fovEnabled = false
local fovValue = 70
local noCamCollisionEnabled = false
_G.DiceNoPlayerCollisionEnabled = _G.DiceNoPlayerCollisionEnabled or false
_G.DiceAntiBodylockEnabled = _G.DiceAntiBodylockEnabled or false
local setAntiBodylockVisual = nil
local customFontVisualEnabled = false
local skyTheme = "Off"
local setPlayerESPVisual = nil
local setTracerESPVisual = nil
local setRagdollCountdownVisual = nil
local setFPSBoostVisual = nil
local setAntiLagVisual = nil
local setNukeOptimiserVisual = nil
local setFOVVisual = nil
local setNoCamCollisionVisual = nil
_G.DiceSetNoPlayerCollisionVisual = _G.DiceSetNoPlayerCollisionVisual or nil
local setCustomFontVisual = nil
local skyValueLabel = nil
local autoLeftEnabled = false
local autoRightEnabled = false
local DEFAULT_SPEED_KEYBINDS = {
SpeedToggle = Enum.KeyCode.Q,
LaggerToggle = Enum.KeyCode.R,
DropBrainrot = Enum.KeyCode.X,
Aimbot = Enum.KeyCode.E,
AntiDesyncAimbot = Enum.KeyCode.V,
AutoLeft = Enum.KeyCode.Z,
AutoRight = Enum.KeyCode.C,
InstantReset = Enum.KeyCode.T,
ToggleUI = Enum.KeyCode.LeftControl,
}
local DEFAULT_TP_DOWN_KEYBIND = Enum.KeyCode.F
local speedKeybinds = {
SpeedToggle = DEFAULT_SPEED_KEYBINDS.SpeedToggle,
LaggerToggle = DEFAULT_SPEED_KEYBINDS.LaggerToggle,
DropBrainrot = DEFAULT_SPEED_KEYBINDS.DropBrainrot,
Aimbot = DEFAULT_SPEED_KEYBINDS.Aimbot,
AntiDesyncAimbot = DEFAULT_SPEED_KEYBINDS.AntiDesyncAimbot,
AutoLeft = DEFAULT_SPEED_KEYBINDS.AutoLeft,
AutoRight = DEFAULT_SPEED_KEYBINDS.AutoRight,
InstantReset = DEFAULT_SPEED_KEYBINDS.InstantReset,
ToggleUI = DEFAULT_SPEED_KEYBINDS.ToggleUI,
}
local speedKeybindButtons = {}
local listeningForSpeedKey = nil
local autoTPEnabled = false
local autoTPHeight = 20
local autoTPConn = nil
local autoTPLastRun = 0
local autoTPClickDebounce = false
local tpDownKeybind = Enum.KeyCode.F
local tpDownKeybindButton = nil
local listeningForTPDownKey = false
local keybindListenStartedAt = 0
local setAutoTPVisual = nil
local function doAutoTPDown(force)
local char=LP.Character;if not char then return end
local hrp=char:FindFirstChild("HumanoidRootPart");if not hrp then return end
local hum2=char:FindFirstChildOfClass("Humanoid");if not hum2 then return end
if not force then
if hum2.FloorMaterial~=Enum.Material.Air then return end
if hrp.Position.Y<autoTPHeight then return end
end
hrp.CFrame=CFrame.new(hrp.Position.X,-7.00,hrp.Position.Z)
*CFrame.Angles(0,select(2,hrp.CFrame:ToEulerAnglesYXZ()),0)
hrp.AssemblyLinearVelocity=Vector3.zero
end
local function _clearAutoTPConnection()
if autoTPConn then
pcall(function() autoTPConn:Disconnect() end)
pcall(function() task.cancel(autoTPConn) end)
autoTPConn = nil
end
end
local function startAutoTP()
autoTPEnabled = true
_clearAutoTPConnection()
autoTPLastRun = 0
autoTPConn = RunService.Heartbeat:Connect(function()
if not autoTPEnabled then
_clearAutoTPConnection()
return
end
local now = tick()
if now - autoTPLastRun < 0.1 then return end
autoTPLastRun = now
pcall(function() doAutoTPDown(false) end)
end)
if setAutoTPVisual then setAutoTPVisual(true) end
end
local function stopAutoTP()
autoTPEnabled = false
_clearAutoTPConnection()
if setAutoTPVisual then setAutoTPVisual(false) end
end
local function runTPFloor()
pcall(function() doAutoTPDown(true) end)
end
local function toggleAutoTP(on)
if on then
startAutoTP()
else
stopAutoTP()
end
saveDiceConfig()
end
function _G.DiceStopAutoTPForAction()
if autoTPEnabled then
stopAutoTP()
pcall(function() if setAutoTPVisual then setAutoTPVisual(false) end end)
pcall(saveDiceConfig)
end
end
local dropBrainrotActive = false
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED = 150
local function runDropBrainrot()
if dropBrainrotActive then return end
if _G.DiceStopAutoTPForAction then _G.DiceStopAutoTPForAction() end
local char = LP.Character
if not char then return end
local root = char:FindFirstChild("HumanoidRootPart")
if not root then return end
dropBrainrotActive = true
local startTime = tick()
local dropConn
dropConn = RunService.Heartbeat:Connect(function()
local currentChar = LP.Character
local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
if not currentChar or not currentRoot then
if dropConn then dropConn:Disconnect() end
dropBrainrotActive = false
return
end
if tick() - startTime >= DROP_ASCEND_DURATION then
if dropConn then dropConn:Disconnect() end
local rayParams = RaycastParams.new()
rayParams.FilterDescendantsInstances = {currentChar}
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local rayResult = workspace:Raycast(currentRoot.Position, Vector3.new(0, -2000, 0), rayParams)
if rayResult then
local hum = currentChar:FindFirstChildOfClass("Humanoid")
local offset = (hum and hum.HipHeight or 2) + (currentRoot.Size.Y / 2)
currentRoot.CFrame = CFrame.new(currentRoot.Position.X, rayResult.Position.Y + offset, currentRoot.Position.Z)
currentRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
currentRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
end
dropBrainrotActive = false
return
end
currentRoot.Velocity = Vector3.new(currentRoot.Velocity.X, DROP_ASCEND_SPEED, currentRoot.Velocity.Z)
end)
end
local infJumpEnabled = false
local antiRagdollEnabled = false
local antiRagdollConn = nil
local unwalkEnabled = false
local unwalkSavedAnimate = nil
local hitHarderAnimEnabled = false
local hitHarderOriginalAnims = {}
local selectedAnimationPack = "OFF"
local AnimationPacks = {
["Zombie"] = {
idle = {{"rbxassetid://616158929", 1}, {"rbxassetid://616158929", 1}},
walk = "rbxassetid://616168032", run = "rbxassetid://616163682",
jump = "rbxassetid://616161997", fall = "rbxassetid://616157476", climb = "rbxassetid://616156119"
},
["Ninja"] = {
idle = {{"rbxassetid://656117400", 1}, {"rbxassetid://656117400", 1}},
walk = "rbxassetid://656121766", run = "rbxassetid://656118852",
jump = "rbxassetid://656117878", fall = "rbxassetid://656115606", climb = "rbxassetid://656114359"
},
["Knight"] = {
idle = {{"rbxassetid://657595757", 1}, {"rbxassetid://657595757", 1}},
walk = "rbxassetid://657552124", run = "rbxassetid://657564596",
jump = "rbxassetid://658409194", fall = "rbxassetid://657600338", climb = "rbxassetid://658360781"
},
["Elder"] = {
idle = {{"rbxassetid://845397899", 1}, {"rbxassetid://845397899", 1}},
walk = "rbxassetid://845403856", run = "rbxassetid://845386501",
jump = "rbxassetid://845398858", fall = "rbxassetid://845397673", climb = "rbxassetid://845392038"
},
["Levitate"] = {
idle = {{"rbxassetid://616006778", 1}, {"rbxassetid://616006778", 1}},
walk = "rbxassetid://616013216", run = "rbxassetid://616013216",
jump = "rbxassetid://616008936", fall = "rbxassetid://616005863", climb = "rbxassetid://616003713"
},
["Astronaut"] = {
idle = {{"rbxassetid://891621366", 1}, {"rbxassetid://891621366", 1}},
walk = "rbxassetid://891636393", run = "rbxassetid://891636393",
jump = "rbxassetid://891627522", fall = "rbxassetid://891617961", climb = "rbxassetid://891609353"
},
["Pirate"] = {
idle = {{"rbxassetid://750781874", 1}, {"rbxassetid://750781874", 1}},
walk = "rbxassetid://750785693", run = "rbxassetid://750783738",
jump = "rbxassetid://750782230", fall = "rbxassetid://750780242", climb = "rbxassetid://750779899"
},
["Toy"] = {
idle = {{"rbxassetid://782841498", 1}, {"rbxassetid://782841498", 1}},
walk = "rbxassetid://782843345", run = "rbxassetid://782842708",
jump = "rbxassetid://782847020", fall = "rbxassetid://782846423", climb = "rbxassetid://782843869"
},
["Vampire"] = {
idle = {{"rbxassetid://1083445855", 1}, {"rbxassetid://1083445855", 1}},
walk = "rbxassetid://1083473930", run = "rbxassetid://1083462077",
jump = "rbxassetid://1083455352", fall = "rbxassetid://1083443587", climb = "rbxassetid://1083439238"
},
["Werewolf"] = {
idle = {{"rbxassetid://1083195517", 1}, {"rbxassetid://1083195517", 1}},
walk = "rbxassetid://1083178339", run = "rbxassetid://1083216690",
jump = "rbxassetid://1083218792", fall = "rbxassetid://1083189019", climb = "rbxassetid://1083182000"
},
["Rthro"] = {
idle = {{"rbxassetid://2510196951", 1}, {"rbxassetid://2510196951", 1}},
walk = "rbxassetid://2510202577", run = "rbxassetid://2510198475",
jump = "rbxassetid://2510197830", fall = "rbxassetid://2510195892", climb = "rbxassetid://2510192778"
},
["Stylish"] = {
idle = {{"rbxassetid://616136790", 1}, {"rbxassetid://616136790", 1}},
walk = "rbxassetid://616146177", run = "rbxassetid://616140816",
jump = "rbxassetid://616139451", fall = "rbxassetid://616134815", climb = "rbxassetid://616133594"
},
}
local AnimationPackList = {"OFF", "Unwalk", "Hit Harder", "Zombie", "Ninja", "Knight", "Elder", "Levitate", "Astronaut", "Pirate", "Toy", "Vampire", "Werewolf", "Rthro", "Stylish"}
local AnimationPackIndex = 1
local OriginalAnims = {}
local enableUnwalk, disableUnwalk, enableHitHarderAnim, disableHitHarderAnim
local HIT_HARDER_ANIMS = {
idle1 = "rbxassetid://133806214992291",
idle2 = "rbxassetid://94970088341563",
walk = "rbxassetid://707897309",
run = "rbxassetid://707861613",
jump = "rbxassetid://116936326516985",
fall = "rbxassetid://116936326516985",
}
local function getAnimate(char)
char = char or LP.Character
return char and char:FindFirstChild("Animate") or nil
end
local function stopCurrentAnimations(char)
local hum = char and char:FindFirstChildOfClass("Humanoid")
if not hum then return end
for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
pcall(function() track:Stop(0) end)
end
end
local function backupAnimations(char)
local animate = getAnimate(char)
if not animate or next(OriginalAnims) ~= nil then return end
local function getId(obj) return obj and obj.AnimationId or nil end
OriginalAnims = {
idle1 = getId(animate.idle and animate.idle:FindFirstChild("Animation1")),
idle2 = getId(animate.idle and animate.idle:FindFirstChild("Animation2")),
walk = getId(animate.walk and animate.walk:FindFirstChild("WalkAnim")),
run = getId(animate.run and animate.run:FindFirstChild("RunAnim")),
jump = getId(animate.jump and animate.jump:FindFirstChild("JumpAnim")),
fall = getId(animate.fall and animate.fall:FindFirstChild("FallAnim")),
climb = getId(animate.climb and animate.climb:FindFirstChild("ClimbAnim")),
}
end
local function setAnimId(obj, id)
if obj and id then pcall(function() obj.AnimationId = id end) end
end
local function reloadAnimate(animate)
if not animate then return end
pcall(function()
animate.Disabled = true
task.wait()
animate.Disabled = false
end)
end
local function resetAnimations()
local char = LP.Character
local animate = getAnimate(char)
if not animate or next(OriginalAnims) == nil then return end
stopCurrentAnimations(char)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), OriginalAnims.idle1)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), OriginalAnims.idle2)
setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), OriginalAnims.walk)
setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), OriginalAnims.run)
setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), OriginalAnims.jump)
setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), OriginalAnims.fall)
setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"), OriginalAnims.climb)
reloadAnimate(animate)
end
local function applyAnimationPack(packName)
selectedAnimationPack = packName or "OFF"
if selectedAnimationPack ~= "Unwalk" and unwalkEnabled then
disableUnwalk()
end
if selectedAnimationPack ~= "Hit Harder" and hitHarderAnimEnabled then
hitHarderAnimEnabled = false
resetAnimations()
end
if selectedAnimationPack == "Unwalk" then
resetAnimations()
enableUnwalk()
return
end
if selectedAnimationPack == "Hit Harder" then
disableUnwalk()
enableHitHarderAnim()
return
end
if selectedAnimationPack == "OFF" then
resetAnimations()
return
end
local pack = AnimationPacks[selectedAnimationPack]
local char = LP.Character
local animate = getAnimate(char)
if not pack or not animate then return end
backupAnimations(char)
stopCurrentAnimations(char)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), pack.idle[1][1])
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), pack.idle[2][1])
setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), pack.walk)
setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), pack.run)
setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), pack.jump)
setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), pack.fall)
setAnimId(animate.climb and animate.climb:FindFirstChild("ClimbAnim"), pack.climb)
reloadAnimate(animate)
end
enableUnwalk = function()
unwalkEnabled = true
local char = LP.Character
local animate = getAnimate(char)
if animate then
if not unwalkSavedAnimate then
unwalkSavedAnimate = animate:Clone()
end
stopCurrentAnimations(char)
animate:Destroy()
end
end
disableUnwalk = function()
unwalkEnabled = false
local char = LP.Character
if char and not char:FindFirstChild("Animate") and unwalkSavedAnimate then
local newAnimate = unwalkSavedAnimate:Clone()
newAnimate.Parent = char
end
end
enableHitHarderAnim = function()
hitHarderAnimEnabled = true
local char = LP.Character
local animate = getAnimate(char)
if not animate then return end
backupAnimations(char)
stopCurrentAnimations(char)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation1"), HIT_HARDER_ANIMS.idle1)
setAnimId(animate.idle and animate.idle:FindFirstChild("Animation2"), HIT_HARDER_ANIMS.idle2)
setAnimId(animate.walk and animate.walk:FindFirstChild("WalkAnim"), HIT_HARDER_ANIMS.walk)
setAnimId(animate.run and animate.run:FindFirstChild("RunAnim"), HIT_HARDER_ANIMS.run)
setAnimId(animate.jump and animate.jump:FindFirstChild("JumpAnim"), HIT_HARDER_ANIMS.jump)
setAnimId(animate.fall and animate.fall:FindFirstChild("FallAnim"), HIT_HARDER_ANIMS.fall)
reloadAnimate(animate)
end
disableHitHarderAnim = function()
hitHarderAnimEnabled = false
resetAnimations()
if selectedAnimationPack ~= "OFF" then
task.wait()
applyAnimationPack(selectedAnimationPack)
end
end
local function startAntiRagdoll()
if antiRagdollConn then return end
antiRagdollConn = RunService.Heartbeat:Connect(function()
if not antiRagdollEnabled then return end
local char = LP.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
local root = char:FindFirstChild("HumanoidRootPart")
if not (hum and root) then return end
local s = hum:GetState()
local ragdolled = (
s == Enum.HumanoidStateType.Physics
or s == Enum.HumanoidStateType.Ragdoll
or s == Enum.HumanoidStateType.FallingDown
)
local endTime = LP:GetAttribute("RagdollEndTime")
if endTime and (endTime - workspace:GetServerTimeNow()) > 0 then
ragdolled = true
end
if ragdolled then
pcall(function()
LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow())
end)
for _, d in ipairs(char:GetDescendants()) do
if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and d.Name:find("RagdollAttachment")) then
pcall(function() d:Destroy() end)
end
end
for _, obj in ipairs(char:GetDescendants()) do
if obj:IsA("Motor6D") and obj.Enabled == false then
obj.Enabled = true
end
end
if hum.Health > 0 then
hum:ChangeState(Enum.HumanoidStateType.Running)
end
workspace.CurrentCamera.CameraSubject = hum
root.Anchored = false
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end
end)
end
local function stopAntiRagdoll()
if antiRagdollConn then
antiRagdollConn:Disconnect()
antiRagdollConn = nil
end
end
local function setAntiRagdoll(on)
antiRagdollEnabled = on and true or false
if antiRagdollEnabled then
startAntiRagdoll()
else
stopAntiRagdoll()
end
end
_G.DiceNormalInfJump = _G.DiceNormalInfJump or {holdPressed=false, holdActive=false, controllerActive=false, mobilePressed=false, mobileActive=false, hooked={}}
function _G.DiceStopNormalInfJumpHoldState()
local S = _G.DiceNormalInfJump
S.holdPressed = false
S.holdActive = false
S.controllerActive = false
S.mobilePressed = false
S.mobileActive = false
end
function _G.DiceApplyNormalInfJumpBoost(boost)
if not infJumpEnabled then return end
local char = LP.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local hum = char and char:FindFirstChildOfClass("Humanoid")
if not root or not hum or hum.Health <= 0 then return end
root.Velocity = Vector3.new(root.Velocity.X, boost or 50, root.Velocity.Z)
end
UserInputService.JumpRequest:Connect(function()
_G.DiceApplyNormalInfJumpBoost(50)
end)
UserInputService.InputBegan:Connect(function(input)
if UserInputService:GetFocusedTextBox() then return end
local S = _G.DiceNormalInfJump
if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
S.holdPressed = true
task.delay(0.12, function()
if _G.DiceNormalInfJump.holdPressed and infJumpEnabled then
_G.DiceNormalInfJump.holdActive = true
_G.DiceApplyNormalInfJumpBoost(50)
end
end)
elseif input.KeyCode == Enum.KeyCode.ButtonA and input.UserInputType.Name:match("^Gamepad") then
S.controllerActive = true
end
end)
UserInputService.InputEnded:Connect(function(input)
local S = _G.DiceNormalInfJump
if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
S.holdPressed = false
S.holdActive = false
end
if input.KeyCode == Enum.KeyCode.ButtonA and input.UserInputType.Name:match("^Gamepad") then
S.controllerActive = false
end
end)
function _G.DiceHookNormalInfMobileJumpButton(obj)
local S = _G.DiceNormalInfJump
if not obj or obj.Name ~= "JumpButton" or not obj:IsA("GuiButton") or S.hooked[obj] then return end
S.hooked[obj] = true
obj.InputBegan:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.Touch or not infJumpEnabled then return end
_G.DiceNormalInfJump.mobilePressed = true
task.delay(0.12, function()
if _G.DiceNormalInfJump.mobilePressed and infJumpEnabled then
_G.DiceNormalInfJump.mobileActive = true
_G.DiceApplyNormalInfJumpBoost(50)
end
end)
end)
obj.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.Touch then
_G.DiceNormalInfJump.mobilePressed = false
_G.DiceNormalInfJump.mobileActive = false
end
end)
obj.AncestryChanged:Connect(function(_, parent)
if not parent then
_G.DiceNormalInfJump.hooked[obj] = nil
_G.DiceNormalInfJump.mobilePressed = false
_G.DiceNormalInfJump.mobileActive = false
end
end)
end
for _, obj in ipairs(PlayerGui:GetDescendants()) do
_G.DiceHookNormalInfMobileJumpButton(obj)
end
PlayerGui.DescendantAdded:Connect(function(obj)
task.defer(_G.DiceHookNormalInfMobileJumpButton, obj)
end)
RunService.Heartbeat:Connect(function()
local S = _G.DiceNormalInfJump
if infJumpEnabled and (S.holdActive or S.mobileActive or S.controllerActive) then
_G.DiceApplyNormalInfJumpBoost(50)
end
end)
setInfJumpInternal = function(on)
infJumpEnabled = on and true or false
if not infJumpEnabled then
_G.DiceStopNormalInfJumpHoldState()
end
end
local diceGuiScaleValue = 0.52
local diceProgressBarScaleValue = 0.83
CONFIG_FILE = "DiceDuels_MainGUI_Config_DefaultsV2.json"
KEYBINDS_CONFIG_FILE = "DiceDuels_Keybinds_DefaultsV2.json"
-- The hub used to save under the old name. Settings are read back from
-- there once when the new file does not exist yet, so renaming the hub
-- does not silently reset everyone; the next save writes the new file.
LEGACY_CONFIG_FILE = "AceDuels_MainGUI_Config_DefaultsV2.json"
LEGACY_KEYBINDS_CONFIG_FILE = "AceDuels_Keybinds_DefaultsV2.json"
_dice_isfile = isfile or (syn and syn.isfile) or function(path)
local ok, result = pcall(function() return readfile(path) end)
return ok and result ~= nil
end
_dice_readfile = readfile or (syn and syn.readfile)
_dice_writefile = writefile or (syn and syn.writefile)
canSaveConfig = (type(_dice_readfile) == "function" and type(_dice_writefile) == "function")

--// Dice Duels Intro + Songs (ported from old source only)
selectedIntroMusic = selectedIntroMusic or 1
_introEnabled = (_introEnabled ~= false)
setIntroVisual = nil
setIntroSongVisual = nil
INTRO_MUSIC_OPTIONS = INTRO_MUSIC_OPTIONS or {
{name="Song 1", url="https://files.catbox.moe/mzvrir.mp3", file="DiceDuelsIntroSong_1.mp3"},
{name="Song 2", url="https://files.catbox.moe/2a7jyx.mp3", file="DiceDuelsIntroSong_2.mp3"},
{name="Song 3", url="https://files.catbox.moe/rcgr9f.mp3", file="DiceDuelsIntroSong_3.mp3"},
{name="Song 4", url="https://files.catbox.moe/iknfuh.mp3", file="DiceDuelsIntroSong_4.mp3"},
{name="Song 5", url="https://files.catbox.moe/6eigoh.mp3", file="DiceDuelsIntroSong_5.mp3"},
{name="Song 6", url="https://files.catbox.moe/dvjtjk.mp3", file="DiceDuelsIntroSong_6.mp3"},
{name="Song 7", url="https://files.catbox.moe/iyw1cb.mp3", file="DiceDuelsIntroSong_7.mp3"},
}
function getIntroSongName()
local opt = INTRO_MUSIC_OPTIONS[selectedIntroMusic]
return opt and opt.name or "No Songs Added"
end
introPreviewSound = nil
introPlaybackSound = nil
introPreviewToken = 0
introPlaybackToken = 0
introSongCache = introSongCache or {}
introSongDownloading = introSongDownloading or {}
function stopIntroPreview()
introPreviewToken = introPreviewToken + 1
if introPreviewSound then
pcall(function() introPreviewSound:Stop() end)
pcall(function() introPreviewSound:Destroy() end)
introPreviewSound = nil
end
end
function stopIntroPlayback()
introPlaybackToken = introPlaybackToken + 1
if introPlaybackSound then
pcall(function() introPlaybackSound:Stop() end)
pcall(function() introPlaybackSound:Destroy() end)
introPlaybackSound = nil
end
end
function _safeNotify(msg)
if showActionNotification then pcall(function() showActionNotification(msg) end) end
end
function cacheIntroSong(option, allowDownload)
if not option or not option.url or option.url == "" then return nil end
if not (writefile and getcustomasset) then return nil end
local fileName = option.file or ("DiceDuelsIntroSong_" .. tostring(option.name or "song") .. ".mp3")
local function loadExisting()
if introSongCache[fileName] then return introSongCache[fileName] end
local hasFile = false
pcall(function() hasFile = isfile and isfile(fileName) end)
if hasFile then
local ok = pcall(function() introSongCache[fileName] = getcustomasset(fileName) end)
if ok and introSongCache[fileName] then return introSongCache[fileName] end
end
return nil
end
local cached = loadExisting()
if cached then return cached end
if allowDownload == false then return nil end
if introSongDownloading[fileName] then
local waitStart = tick()
while introSongDownloading[fileName] and tick() - waitStart < 12 do task.wait(0.05) end
cached = loadExisting()
if cached then return cached end
end
introSongDownloading[fileName] = true
local ok = pcall(function()
local data = game:HttpGet(option.url)
if data and #data > 0 then
writefile(fileName, data)
introSongCache[fileName] = getcustomasset(fileName)
end
end)
introSongDownloading[fileName] = nil
if ok and introSongCache[fileName] then return introSongCache[fileName] end
return loadExisting()
end
function preloadIntroSongs()
task.spawn(function()
cacheIntroSong(INTRO_MUSIC_OPTIONS[selectedIntroMusic], true)
for _, option in ipairs(INTRO_MUSIC_OPTIONS) do
if option ~= INTRO_MUSIC_OPTIONS[selectedIntroMusic] then
cacheIntroSong(option, true)
task.wait(0.05)
end
end
end)
end
function makeIntroSoundFromId(soundId, name, parent)
if not soundId then return nil end
local sound = Instance.new("Sound")
sound.Name = name or "DiceDuelsIntroMusic"
sound.Volume = 0.65
sound.Looped = false
sound.SoundId = soundId
sound.Parent = parent or SoundService
return sound
end
function createIntroSound(option, fileName, parent, allowDownload)
if not option then return nil end
local soundId = cacheIntroSong(option, allowDownload)
if not soundId then return nil end
return makeIntroSoundFromId(soundId, fileName, parent)
end
function previewIntroMusic(index)
stopIntroPreview()
stopIntroPlayback()
if not INTRO_MUSIC_OPTIONS[index] then _safeNotify("ADD SONG LINKS"); return end
local token = introPreviewToken
task.spawn(function()
local option = INTRO_MUSIC_OPTIONS[index]
local sound = createIntroSound(option, "DiceDuelsIntroPreview_" .. tostring(token), SoundService, true)
if token ~= introPreviewToken then if sound then sound:Destroy() end; return end
introPreviewSound = sound
if not sound then _safeNotify("SONG LOADING..."); return end
sound.TimePosition = 0
pcall(function() sound:Play() end)
task.delay(15, function() if token == introPreviewToken then stopIntroPreview() end end)
end)
end
function playIntroMusic()
stopIntroPreview()
stopIntroPlayback()
if not _introEnabled then return end
local option = INTRO_MUSIC_OPTIONS[selectedIntroMusic]
if not option then return end
local token = introPlaybackToken
task.spawn(function()
local sound = createIntroSound(option, "DiceDuelsIntroMusic_" .. tostring(token), SoundService, true)
if token ~= introPlaybackToken or not _introEnabled then if sound then pcall(function() sound:Destroy() end) end; return end
introPlaybackSound = sound
if not sound then _safeNotify("SONG FAILED"); return end
sound.TimePosition = 0
local loadStart = tick()
while sound and not sound.IsLoaded and tick() - loadStart < 10 do task.wait(0.05) end
pcall(function() sound:Play() end)
task.delay(15, function() if token == introPlaybackToken then stopIntroPlayback() end end)
end)
end
preloadIntroSongs()

savedConfig = {}
_G.DiceGuiLocked = _G.DiceGuiLocked == true
_G.DiceHideMobileButtons = _G.DiceHideMobileButtons == true
_G.DiceMobileButtonScale = 0.75
_G.DiceMobileButtonPositions = _G.DiceMobileButtonPositions or {}
savedMainPositionTable = nil
savedMiniPositionTable = nil
function udim2ToTable(u)
return {xs = u.X.Scale, xo = u.X.Offset, ys = u.Y.Scale, yo = u.Y.Offset}
end
function tableToUDim2(t, fallback)
if type(t) == "table" then
return UDim2.new(tonumber(t.xs) or 0, tonumber(t.xo) or 0, tonumber(t.ys) or 0, tonumber(t.yo) or 0)
end
return fallback
end
function collectDiceMobileButtonPositions()
-- The buttons live in one draggable panel now, so only its position is
-- worth storing. Older configs held a position per button; those keys
-- are simply ignored.
local out = {}
if _G.DiceMobilePanel then
out.panel = udim2ToTable(_G.DiceMobilePanel.Position)
end
if next(out) == nil and type(_G.DiceMobileButtonPositions) == "table" then
return _G.DiceMobileButtonPositions
end
_G.DiceMobileButtonPositions = out
return out
end
function keyToString(key)
if not key then return "None" end
return tostring(key):gsub("Enum.KeyCode.", "")
end
function stringToKeyCode(value)
if type(value) ~= "string" or value == "" or value == "None" then return nil end
return Enum.KeyCode[value]
end
function keybindsToTable()
local out = {}
for keyId in pairs(DEFAULT_SPEED_KEYBINDS) do
out[keyId] = keyToString(speedKeybinds[keyId])
end
for keyId, key in pairs(speedKeybinds) do
out[keyId] = keyToString(key)
end
return out
end
function collectDiceKeybindConfig()
return {
keybinds = keybindsToTable(),
tpDownKeybind = keyToString(tpDownKeybind),
}
end
function applySavedKeybinds(t)
if type(t) ~= "table" then return end
for keyId in pairs(speedKeybinds) do
if t[keyId] ~= nil then
speedKeybinds[keyId] = stringToKeyCode(t[keyId])
end
end
end
function applyDefaultDiceKeybinds()
for keyId, key in pairs(DEFAULT_SPEED_KEYBINDS) do
speedKeybinds[keyId] = key
end
tpDownKeybind = DEFAULT_TP_DOWN_KEYBIND
end
function collectDiceConfig()
return {
mainPosition = savedMainPositionTable,
keybinds = keybindsToTable(),
tpDownKeybind = keyToString(tpDownKeybind),
NS = NS,
CS = CS,
LAGGER_SPEED = LAGGER_SPEED,
LAGGER_CARRY_SPEED = LAGGER_CARRY_SPEED,
currentSpeedMode = currentSpeedMode,
diceMatchWalkSpeed = diceMatchWalkSpeed == true,
autoCarrySpeedEnabled = autoCarrySpeedEnabled == true,
autoTPEnabled = autoTPEnabled,
autoTPHeight = autoTPHeight,
infJumpEnabled = infJumpEnabled,
antiRagdollEnabled = antiRagdollEnabled,
selectedAnimationPack = selectedAnimationPack,
selectedStealMode = selectedStealMode,
autoStealEnabled = autoStealEnabled,
autoStealRadius = autoStealRadius,
diceStealRadii = _G.DiceStealRadii,
selectedAimbotMode = selectedAimbotMode,
AIMBOT_SPEED = AIMBOT_SPEED,
LAGGER_AIMBOT_SPEED = LAGGER_AIMBOT_SPEED,
ANTI_BYPASS_AIMBOT_SPEED = _G.DiceAntiBypassAimbotSpeed,
ANTI_BYPASS_LAGGER_AIMBOT_SPEED = _G.DiceAntiBypassLaggerAimbotSpeed,
ANTI_DESYNC_AIMBOT_SPEED = ANTI_DESYNC_AIMBOT_SPEED,
autoSwingEnabled = autoSwingEnabled,
mirrorTPDownEnabled = mirrorTPDownEnabled,
normalAimbotEnabled = _G.DiceNormalAimbotOn == true,
antiBypassAimbotEnabled = _G.DiceAntiBypassAimbotOn == true,
antiDesyncAutoSwingEnabled = antiDesyncAutoSwingEnabled,
antiDesyncAimbotEnabled = _G.DiceAntiDesyncAimbotOn == true,
batCounterEnabled = batCounterEnabled,
medCounterEnabled = medCounterEnabled,
safeMode = antiKickEnabled == true,
autoResetOnMedEnabled = autoResetOnMedEnabled,
espEnabled = espEnabled,
showTracerEnabled = showTracerEnabled,
ragdollCountdownEnabled = ragdollCountdownEnabled,
fpsBoostEnabled = fpsBoostEnabled,
antiLagVisualEnabled = antiLagVisualEnabled,
nukeOptimiserEnabled = nukeOptimiserEnabled,
fovEnabled = fovEnabled,
fovValue = fovValue,
noCamCollisionEnabled = noCamCollisionEnabled,
noPlayerCollisionEnabled = _G.DiceNoPlayerCollisionEnabled,
antiBodylockEnabled = _G.DiceAntiBodylockEnabled == true,
customFontVisualEnabled = false,
skyTheme = skyTheme,
lightningEnabled = _G.DiceLightningEnabled ~= false,
autoLeftEnabled = autoLeftEnabled,
autoRightEnabled = autoRightEnabled,
diceGuiScaleValue = diceGuiScaleValue,
diceProgressBarScaleValue = diceProgressBarScaleValue,
introEnabled = _introEnabled == true,
selectedIntroMusic = selectedIntroMusic,
guiLocked = _G.DiceGuiLocked == true,
hideMobileButtons = _G.DiceHideMobileButtons == true,
diceMobileButtonScale = _G.DiceMobileButtonScale,
mobileButtonPositions = collectDiceMobileButtonPositions(),
}
end
function saveDiceConfig()
if not canSaveConfig then return end
pcall(function()
_dice_writefile(CONFIG_FILE, HttpService:JSONEncode(collectDiceConfig()))
_dice_writefile(KEYBINDS_CONFIG_FILE, HttpService:JSONEncode(collectDiceKeybindConfig()))
end)
end
function loadDiceConfig()
if not canSaveConfig then return end
local configPath = CONFIG_FILE
if not _dice_isfile(configPath) then
if not _dice_isfile(LEGACY_CONFIG_FILE) then return end
configPath = LEGACY_CONFIG_FILE
end
local ok, data = pcall(function()
return HttpService:JSONDecode(_dice_readfile(configPath))
end)
if not ok or type(data) ~= "table" then return end
savedConfig = data
local keybindData = data
pcall(function()
local keybindPath = nil
if _dice_isfile(KEYBINDS_CONFIG_FILE) then
keybindPath = KEYBINDS_CONFIG_FILE
elseif _dice_isfile(LEGACY_KEYBINDS_CONFIG_FILE) then
keybindPath = LEGACY_KEYBINDS_CONFIG_FILE
end
if keybindPath then
local kb = HttpService:JSONDecode(_dice_readfile(keybindPath))
if type(kb) == "table" then keybindData = kb end
end
end)
savedMainPositionTable = data.mainPosition
savedMiniPositionTable = nil
_G.DiceGuiLocked = data.guiLocked == true
_G.DiceHideMobileButtons = data.hideMobileButtons == true
_G.DiceMobileButtonScale = math.clamp(tonumber(data.diceMobileButtonScale) or tonumber(_G.DiceMobileButtonScale) or 0.75, 0.30, 1.35)
_G.DiceMobileButtonPositions = type(data.mobileButtonPositions) == "table" and data.mobileButtonPositions or {}
applySavedKeybinds(keybindData.keybinds)
if keybindData.tpDownKeybind ~= nil then
if tostring(keybindData.tpDownKeybind) == "None" then
tpDownKeybind = nil
else
tpDownKeybind = stringToKeyCode(keybindData.tpDownKeybind) or DEFAULT_TP_DOWN_KEYBIND
end
end
for keyId, defaultKey in pairs(DEFAULT_SPEED_KEYBINDS) do
local savedKeys = keybindData and keybindData.keybinds
if (not savedKeys or savedKeys[keyId] == nil) and speedKeybinds[keyId] == nil then
speedKeybinds[keyId] = defaultKey
end
end
NS = tonumber(data.NS) or NS
CS = tonumber(data.CS) or CS
LAGGER_SPEED = tonumber(data.LAGGER_SPEED) or LAGGER_SPEED
LAGGER_CARRY_SPEED = tonumber(data.LAGGER_CARRY_SPEED) or LAGGER_CARRY_SPEED
currentSpeedMode = data.currentSpeedMode or currentSpeedMode
if currentSpeedMode ~= "Normal" and currentSpeedMode ~= "Carry" and currentSpeedMode ~= "Lagger" and currentSpeedMode ~= "Lagger Carry" then currentSpeedMode = "Normal" end
if data.diceMatchWalkSpeed ~= nil then diceMatchWalkSpeed = data.diceMatchWalkSpeed == true end
autoCarrySpeedEnabled = data.autoCarrySpeedEnabled == true
autoTPEnabled = data.autoTPEnabled == true
autoTPHeight = tonumber(data.autoTPHeight) or autoTPHeight
infJumpEnabled = data.infJumpEnabled == true
antiRagdollEnabled = data.antiRagdollEnabled == true
selectedAnimationPack = data.selectedAnimationPack or selectedAnimationPack
selectedStealMode = data.selectedStealMode or selectedStealMode
if selectedStealMode ~= "Semi" then selectedStealMode = "Normal" end
autoStealEnabled = data.autoStealEnabled == true
if type(data.diceStealRadii) == "table" then
_G.DiceStealRadii.Normal = tonumber(data.diceStealRadii.Normal) or _G.DiceStealRadii.Normal or 62
_G.DiceStealRadii.Semi = tonumber(data.diceStealRadii.Semi) or _G.DiceStealRadii.Semi or 9
end
autoStealRadius = tonumber(data.autoStealRadius) or autoStealRadius
if selectedStealMode == "Normal" then
_G.DiceStealRadii.Normal = tonumber(autoStealRadius) or _G.DiceStealRadii.Normal or 62
autoStealRadius = _G.DiceStealRadii.Normal
else
autoStealRadius = _G.DiceStealRadii.Semi or 9
end
selectedAimbotMode = data.selectedAimbotMode or selectedAimbotMode
if selectedAimbotMode ~= "Anti Bypass" then selectedAimbotMode = "Normal" end
AIMBOT_SPEED = tonumber(data.AIMBOT_SPEED) or AIMBOT_SPEED
LAGGER_AIMBOT_SPEED = tonumber(data.LAGGER_AIMBOT_SPEED) or LAGGER_AIMBOT_SPEED
_G.DiceAntiBypassAimbotSpeed = tonumber(data.ANTI_BYPASS_AIMBOT_SPEED) or _G.DiceAntiBypassAimbotSpeed or 58
if data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED == nil or tonumber(data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED) == 58 then
_G.DiceAntiBypassLaggerAimbotSpeed = 40
else
_G.DiceAntiBypassLaggerAimbotSpeed = tonumber(data.ANTI_BYPASS_LAGGER_AIMBOT_SPEED) or 40
end
ANTI_DESYNC_AIMBOT_SPEED = tonumber(data.ANTI_DESYNC_AIMBOT_SPEED) or ANTI_DESYNC_AIMBOT_SPEED or 58
autoSwingEnabled = data.autoSwingEnabled == true
mirrorTPDownEnabled = data.mirrorTPDownEnabled == true
_G.DiceNormalAimbotOn = data.normalAimbotEnabled == true
_G.DiceAntiBypassAimbotOn = data.antiBypassAimbotEnabled == true
antiDesyncAutoSwingEnabled = data.antiDesyncAutoSwingEnabled == true
_G.DiceAntiDesyncAimbotOn = data.antiDesyncAimbotEnabled == true
batCounterEnabled = data.batCounterEnabled == true
medCounterEnabled = data.medCounterEnabled == true
antiKickEnabled = data.safeMode == true
autoResetOnMedEnabled = data.autoResetOnMedEnabled == true
espEnabled = data.espEnabled == true
showTracerEnabled = data.showTracerEnabled == true
ragdollCountdownEnabled = data.ragdollCountdownEnabled == true
fpsBoostEnabled = data.fpsBoostEnabled == true
antiLagVisualEnabled = data.antiLagVisualEnabled == true
nukeOptimiserEnabled = data.nukeOptimiserEnabled == true
fovEnabled = data.fovEnabled == true
fovValue = tonumber(data.fovValue) or fovValue
noCamCollisionEnabled = data.noCamCollisionEnabled == true
_G.DiceNoPlayerCollisionEnabled = data.noPlayerCollisionEnabled == true
_G.DiceAntiBodylockEnabled = data.antiBodylockEnabled == true
customFontVisualEnabled = false
skyTheme = (type(data.skyTheme) == "string" and data.skyTheme) or skyTheme
if data.lightningEnabled ~= nil then _G.DiceLightningEnabled = data.lightningEnabled ~= false else _G.DiceLightningEnabled = true end
autoLeftEnabled = data.autoLeftEnabled == true
autoRightEnabled = data.autoRightEnabled == true
if data.introEnabled ~= nil then _introEnabled = data.introEnabled == true end
if data.selectedIntroMusic and INTRO_MUSIC_OPTIONS[data.selectedIntroMusic] then selectedIntroMusic = data.selectedIntroMusic end
if autoLeftEnabled and autoRightEnabled then autoRightEnabled = false end
end
loadDiceConfig()
local function syncAnimationPackIndex()
for i, name in ipairs(AnimationPackList) do
if name == selectedAnimationPack then
AnimationPackIndex = i
return
end
end
selectedAnimationPack = "OFF"
AnimationPackIndex = 1
end
local function applySavedAnimationPackToCharacter(char)
syncAnimationPackIndex()
if refreshAnimationPackRow then pcall(refreshAnimationPackRow) end
if not char then char = LP.Character end
if not char then return end
local animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 6)
if not animate then return end
task.wait(0.2)
OriginalAnims = {}
unwalkSavedAnimate = nil
if selectedAnimationPack and selectedAnimationPack ~= "OFF" then
pcall(function() applyAnimationPack(selectedAnimationPack) end)
else
pcall(function() resetAnimations() end)
end
end
syncAnimationPackIndex()
task.defer(function()
applySavedAnimationPackToCharacter(LP.Character)
end)
LP.CharacterAdded:Connect(function(char)
task.wait(0.65)
applySavedAnimationPackToCharacter(char)
end)
_G.DiceAutoResetOnMed = _G.DiceAutoResetOnMed or {}
_G.DiceAutoResetOnMed.conns = _G.DiceAutoResetOnMed.conns or {}
_G.DiceAutoResetOnMed.enabled = autoResetOnMedEnabled == true
_G.DiceAutoResetOnMed.medTriggered = false
_G.DiceAutoResetOnMed.lastFire = _G.DiceAutoResetOnMed.lastFire or 0
_G.DiceAutoResetOnMed.cooldown = 2.25
_G.DiceAutoResetOnMed.charAddedConn = _G.DiceAutoResetOnMed.charAddedConn
_G.DiceCursedResetGuid = _G.DiceCursedResetGuid or "f888ee6e-c86d-46e1-93d7-0639d6635d42"
_G.DiceCursedResetRemote = _G.DiceCursedResetRemote or nil
pcall(function()
if hookfunction and newcclosure and not _G.DiceCursedResetHooked and not _G.DiceAutoResetOnMed.remoteHooked then
_G.DiceAutoResetOnMed.remoteHooked = true
local oldFire
oldFire = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
if not _G.DiceCursedResetRemote
and typeof(self) == "Instance"
and self:IsA("RemoteEvent")
and self.Name:sub(1, 3) == "RE/" then
_G.DiceCursedResetRemote = self
end
return oldFire(self, ...)
end))
end
end)
function _G.DiceFindCursedResetRemote()
if _G.DiceCursedResetRemote then return _G.DiceCursedResetRemote end
for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
if desc:IsA("RemoteEvent") and desc.Name:sub(1, 3) == "RE/" then
_G.DiceCursedResetRemote = desc
break
end
end
return _G.DiceCursedResetRemote
end
function _G.DiceAutoResetCursedInstaReset()
local remote = _G.DiceFindCursedResetRemote and _G.DiceFindCursedResetRemote() or _G.DiceCursedResetRemote
if not remote then return end
local character = LP.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if humanoid and humanoid.Health <= 0 then
pcall(function()
remote:FireServer(_G.DiceCursedResetGuid, LP, "balloon")
end)
return
end
local resetDetected = false
local resetConns = {}
if humanoid then
table.insert(resetConns, humanoid.Died:Connect(function()
resetDetected = true
end))
table.insert(resetConns, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
if humanoid.Health <= 0 then
resetDetected = true
end
end))
end
if character then
table.insert(resetConns, character.AncestryChanged:Connect(function(_, parent)
if not parent then
resetDetected = true
end
end))
end
task.spawn(function()
for _ = 1, 10 do
if resetDetected then break end
pcall(function()
remote:FireServer(_G.DiceCursedResetGuid, LP, "balloon")
end)
task.wait(0.05)
end
for _, conn in ipairs(resetConns) do
pcall(function()
conn:Disconnect()
end)
end
end)
end
function _G.DiceAutoResetShouldFire(part)
local state = _G.DiceAutoResetOnMed
if not state or not state.enabled then return false end
if state.medTriggered then return false end
if tick() - (state.lastFire or 0) < (state.cooldown or 2.25) then return false end
if not part or not part.Parent then return false end
if part:FindFirstAncestorOfClass("Tool") or part:FindFirstAncestorOfClass("Accessory") then
return false
end
return part.Anchored and part.Transparency == 1
end
function _G.DiceAutoResetFireOnce(part)
if not _G.DiceAutoResetShouldFire(part) then return end
local state = _G.DiceAutoResetOnMed
state.medTriggered = true
state.lastFire = tick()
task.delay(2.3, function()
if state.enabled then
if _G.DiceAutoResetCursedInstaReset then
_G.DiceAutoResetCursedInstaReset()
elseif cursedInstaReset then
cursedInstaReset()
end
end
end)
end
function _G.DiceAutoResetOnAnchorChanged(part)
return part:GetPropertyChangedSignal("Anchored"):Connect(function()
_G.DiceAutoResetFireOnce(part)
end)
end
function _G.DiceStopAutoResetOnMed()
local state = _G.DiceAutoResetOnMed
if not state then return end
for _, conn in ipairs(state.conns or {}) do
pcall(function()
conn:Disconnect()
end)
end
state.conns = {}
state.medTriggered = false
end
function _G.DiceStartAutoResetOnMed(char)
local state = _G.DiceAutoResetOnMed
if not state then return end
_G.DiceStopAutoResetOnMed()
state.medTriggered = false
char = char or LP.Character
if not char then return end
for _, part in ipairs(char:GetDescendants()) do
if part:IsA("BasePart") then
table.insert(state.conns, _G.DiceAutoResetOnAnchorChanged(part))
_G.DiceAutoResetFireOnce(part)
end
end
table.insert(state.conns, char.DescendantAdded:Connect(function(part)
if part:IsA("BasePart") then
table.insert(state.conns, _G.DiceAutoResetOnAnchorChanged(part))
_G.DiceAutoResetFireOnce(part)
end
end))
table.insert(state.conns, char.AncestryChanged:Connect(function(_, parent)
if not parent then
state.medTriggered = false
end
end))
end
function _G.DiceEnableAutoResetOnMed()
autoResetOnMedEnabled = true
_G.DiceAutoResetOnMed.enabled = true
_G.DiceStartAutoResetOnMed(LP.Character)
end
function _G.DiceDisableAutoResetOnMed()
autoResetOnMedEnabled = false
_G.DiceAutoResetOnMed.enabled = false
_G.DiceStopAutoResetOnMed()
end
function _G.DiceSetAutoResetOnMed(state, noSave)
autoResetOnMedEnabled = state == true
if autoResetOnMedEnabled then
_G.DiceEnableAutoResetOnMed()
else
_G.DiceDisableAutoResetOnMed()
end
if setAutoResetOnMedVisual then
setAutoResetOnMedVisual(autoResetOnMedEnabled)
end
if not noSave and saveDiceConfig then saveDiceConfig() end
end
function enableAutoResetOnMed()
_G.DiceSetAutoResetOnMed(true)
end
function disableAutoResetOnMed()
_G.DiceSetAutoResetOnMed(false)
end
function toggleAutoResetOnMed(on)
_G.DiceSetAutoResetOnMed(on == true)
end
if not _G.DiceAutoResetOnMed.charAddedConn then
_G.DiceAutoResetOnMed.charAddedConn = LP.CharacterAdded:Connect(function(char)
if _G.DiceAutoResetOnMed and _G.DiceAutoResetOnMed.enabled then
task.wait(0.25)
_G.DiceStartAutoResetOnMed(char)
end
end)
end
_G.DiceCounterState = _G.DiceCounterState or {}
_G.DiceCounterState.batConn = nil
_G.DiceCounterState.batDebounce = false
_G.DiceCounterState.medConns = _G.DiceCounterState.medConns or {}
_G.DiceCounterState.medDebounce = false
_G.DiceCounterState.medLastUsed = _G.DiceCounterState.medLastUsed or 0
_G.DiceMedusaCooldown = 25
function _G.DiceFindMedusa()
local c = LP.Character
if not c then return nil end
for _, t in ipairs(c:GetChildren()) do
if t:IsA("Tool") then
local n = t.Name:lower()
if n:find("medusa") or n:find("head") or n:find("stone") then return t end
end
end
local bp = LP:FindFirstChild("Backpack") or LP:FindFirstChildOfClass("Backpack")
if bp then
for _, t in ipairs(bp:GetChildren()) do
if t:IsA("Tool") then
local n = t.Name:lower()
if n:find("medusa") or n:find("head") or n:find("stone") then return t end
end
end
end
return nil
end
function _G.DiceUseMedusaCounter()
if not medCounterEnabled then return end
if _G.DiceCounterState.medDebounce then return end
if tick() - (_G.DiceCounterState.medLastUsed or 0) < _G.DiceMedusaCooldown then return end
local c = LP.Character
if not c then return end
_G.DiceCounterState.medDebounce = true
local med = _G.DiceFindMedusa()
if not med then
_G.DiceCounterState.medDebounce = false
return
end
if med.Parent ~= c then
local hum = c:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum:EquipTool(med) end) end
task.wait(0.05)
end
pcall(function() med:Activate() end)
_G.DiceCounterState.medLastUsed = tick()
_G.DiceCounterState.medDebounce = false
end
function _G.DiceOnMedusaAnchorChanged(part)
return part:GetPropertyChangedSignal("Anchored"):Connect(function()
if medCounterEnabled and part.Anchored and part.Transparency == 1 then
_G.DiceUseMedusaCounter()
end
end)
end
function _G.DiceStartMedCounter(char)
_G.DiceStopMedCounter()
char = char or LP.Character
if not char then return end
for _, part in ipairs(char:GetDescendants()) do
if part:IsA("BasePart") then
table.insert(_G.DiceCounterState.medConns, _G.DiceOnMedusaAnchorChanged(part))
end
end
table.insert(_G.DiceCounterState.medConns, char.DescendantAdded:Connect(function(part)
if part:IsA("BasePart") then
table.insert(_G.DiceCounterState.medConns, _G.DiceOnMedusaAnchorChanged(part))
end
end))
end
function _G.DiceStopMedCounter()
for _, c in pairs(_G.DiceCounterState.medConns or {}) do
pcall(function() c:Disconnect() end)
end
_G.DiceCounterState.medConns = {}
_G.DiceCounterState.medDebounce = false
end
_G.DiceBatCounterSlapList = {"Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap", "Emerald Slap", "Ruby Slap", "Dark Matter Slap", "Flame Slap", "Nuclear Slap", "Galaxy Slap", "Glitched Slap"}
function _G.DiceFindBatForCounter()
local c = LP.Character
if not c then return nil end
local bp = LP:FindFirstChildOfClass("Backpack") or LP:FindFirstChild("Backpack")
for _, name in ipairs(_G.DiceBatCounterSlapList) do
local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
if t then return t end
end
for _, ch in ipairs(c:GetChildren()) do
if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
end
if bp then
for _, ch in ipairs(bp:GetChildren()) do
if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end
end
end
return nil
end
function _G.DiceSwingBatForCounter(bat, char)
if not bat or not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if bat.Parent ~= char then
if hum then pcall(function() hum:EquipTool(bat) end) end
task.wait(0.05)
end
local remote = bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
if remote and remote:IsA("RemoteEvent") then
pcall(function() remote:FireServer() end)
task.wait(0.15)
pcall(function() remote:FireServer() end)
else
pcall(function() bat:Activate() end)
task.wait(0.15)
pcall(function() bat:Activate() end)
end
end
function _G.DiceCounterIsRagdoll(hum)
if not hum then return false end
local st = hum:GetState()
return st == Enum.HumanoidStateType.Physics
or st == Enum.HumanoidStateType.Ragdoll
or st == Enum.HumanoidStateType.FallingDown
or hum.PlatformStand == true
end
function _G.DiceStartBatCounter()
if _G.DiceCounterState.batConn then return end
_G.DiceCounterState.batDebounce = false
_G.DiceCounterState.batConn = RunService.Heartbeat:Connect(function()
if not batCounterEnabled then return end
if _G.DiceCounterState.batDebounce then return end
local char = LP.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
if _G.DiceCounterIsRagdoll(hum) then
_G.DiceCounterState.batDebounce = true
task.spawn(function()
local bat = _G.DiceFindBatForCounter()
if bat then _G.DiceSwingBatForCounter(bat, char) end
task.wait(0.5)
_G.DiceCounterState.batDebounce = false
end)
end
end)
end
function _G.DiceStopBatCounter()
if _G.DiceCounterState.batConn then
_G.DiceCounterState.batConn:Disconnect()
_G.DiceCounterState.batConn = nil
end
_G.DiceCounterState.batDebounce = false
end
startBatCounter = _G.DiceStartBatCounter
stopBatCounter = _G.DiceStopBatCounter
setupMedusaCounter = _G.DiceStartMedCounter
stopMedusaCounter = _G.DiceStopMedCounter
_G.DiceNoPlayerCollisionState = _G.DiceNoPlayerCollisionState or {connections = {}}
function _G.DiceSetOtherPlayerCollision(state)
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
for _, part in ipairs(plr.Character:GetDescendants()) do
if part:IsA("BasePart") then
pcall(function() part.CanCollide = state end)
end
end
end
end
end
function enableNoPlayerCollision()
if _G.DiceNoPlayerCollisionState.running then return end
_G.DiceNoPlayerCollisionEnabled = true
_G.DiceNoPlayerCollisionState.running = true
for _, conn in ipairs(_G.DiceNoPlayerCollisionState.connections or {}) do
pcall(function() conn:Disconnect() end)
end
_G.DiceNoPlayerCollisionState.connections = {}
_G.DiceSetOtherPlayerCollision(false)
table.insert(_G.DiceNoPlayerCollisionState.connections, LP.CharacterAdded:Connect(function()
task.wait(0.5)
if _G.DiceNoPlayerCollisionEnabled then _G.DiceSetOtherPlayerCollision(false) end
end))
table.insert(_G.DiceNoPlayerCollisionState.connections, Players.PlayerAdded:Connect(function(plr)
local c = plr.CharacterAdded:Connect(function()
task.wait(0.5)
if _G.DiceNoPlayerCollisionEnabled then _G.DiceSetOtherPlayerCollision(false) end
end)
table.insert(_G.DiceNoPlayerCollisionState.connections, c)
end))
local collisionScanElapsed = 0
table.insert(_G.DiceNoPlayerCollisionState.connections, RunService.Heartbeat:Connect(function(dt)
if not _G.DiceNoPlayerCollisionEnabled then return end
collisionScanElapsed = collisionScanElapsed + (dt or 0)
if collisionScanElapsed < 0.25 then return end
collisionScanElapsed = 0
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
for _, part in ipairs(plr.Character:GetDescendants()) do
if part:IsA("BasePart") and part.CanCollide == true then
pcall(function() part.CanCollide = false end)
end
end
end
end
end))
end
function disableNoPlayerCollision()
if not _G.DiceNoPlayerCollisionState.running then
_G.DiceNoPlayerCollisionEnabled = false
return
end
_G.DiceNoPlayerCollisionEnabled = false
_G.DiceNoPlayerCollisionState.running = false
for _, conn in ipairs(_G.DiceNoPlayerCollisionState.connections or {}) do
pcall(function() conn:Disconnect() end)
end
_G.DiceNoPlayerCollisionState.connections = {}
_G.DiceSetOtherPlayerCollision(true)
end
_G.DiceAntiBodylockState = _G.DiceAntiBodylockState or {connections = {}, running = false}
function enableAntiBodylock()
if _G.DiceAntiBodylockState.running then return end
_G.DiceAntiBodylockEnabled = true
_G.DiceAntiBodylockState.running = true
for _, conn in ipairs(_G.DiceAntiBodylockState.connections or {}) do
pcall(function() conn:Disconnect() end)
end
_G.DiceAntiBodylockState.connections = {}
local function stripLockConstraints(char)
if not char then return end
for _, obj in ipairs(char:GetDescendants()) do
pcall(function()
if (obj:IsA("BodyPosition") or obj:IsA("BodyGyro") or obj:IsA("BodyVelocity")
or obj:IsA("AlignPosition") or obj:IsA("AlignOrientation")
or obj:IsA("LineForce") or obj:IsA("VectorForce")
or obj:IsA("SpringConstraint") or obj:IsA("RopeConstraint")
or obj:IsA("RodConstraint")) then
if obj.Name ~= "DiceInternal" then
obj:Destroy()
end
elseif obj:IsA("WeldConstraint") or obj:IsA("Weld") then
local p0 = obj.Part0
local p1 = obj.Part1
if p0 and p1 then
local isOwn0 = p0:IsDescendantOf(char)
local isOwn1 = p1:IsDescendantOf(char)
if (isOwn0 and not isOwn1) or (isOwn1 and not isOwn0) then
obj:Destroy()
end
end
end
end)
end
end
local function detachForeignAttachments(char)
if not char then return end
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hrp then return end
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
local otherRoot = plr.Character:FindFirstChild("HumanoidRootPart")
if otherRoot then
local dist = (hrp.Position - otherRoot.Position).Magnitude
if dist < 2.5 then
pcall(function()
otherRoot.CFrame = otherRoot.CFrame * CFrame.new(0, 0, 4)
end)
end
end
for _, obj in ipairs(plr.Character:GetDescendants()) do
pcall(function()
if obj:IsA("Attachment") then
local target = obj:FindFirstChildOfClass("AlignPosition") or obj:FindFirstChildOfClass("AlignOrientation")
if target then
local a0 = target:FindFirstChild("Attachment0") or (target.Attachment0)
local a1 = target:FindFirstChild("Attachment1") or (target.Attachment1)
pcall(function()
if a0 and a0:IsDescendantOf(char) then target:Destroy() end
if a1 and a1:IsDescendantOf(char) then target:Destroy() end
end)
end
end
if (obj:IsA("WeldConstraint") or obj:IsA("Weld")) then
local p0, p1 = obj.Part0, obj.Part1
if p0 and p1 then
if p0:IsDescendantOf(char) or p1:IsDescendantOf(char) then
obj:Destroy()
end
end
end
end)
end
end
end
end
local scanElapsed = 0
table.insert(_G.DiceAntiBodylockState.connections, RunService.Heartbeat:Connect(function(dt)
if not _G.DiceAntiBodylockEnabled then return end
scanElapsed = scanElapsed + (dt or 0)
if scanElapsed < 0.08 then return end
scanElapsed = 0
local char = LP.Character
if not char then return end
pcall(stripLockConstraints, char)
pcall(detachForeignAttachments, char)
end))
table.insert(_G.DiceAntiBodylockState.connections, LP.CharacterAdded:Connect(function(char)
task.wait(0.3)
if _G.DiceAntiBodylockEnabled then
pcall(stripLockConstraints, char)
end
end))
table.insert(_G.DiceAntiBodylockState.connections, workspace.DescendantAdded:Connect(function(obj)
if not _G.DiceAntiBodylockEnabled then return end
local char = LP.Character
if not char then return end
task.defer(function()
if not _G.DiceAntiBodylockEnabled then return end
pcall(function()
if not obj or not obj.Parent then return end
if not obj:IsDescendantOf(char) then return end
if (obj:IsA("BodyPosition") or obj:IsA("BodyGyro") or obj:IsA("BodyVelocity")
or obj:IsA("AlignPosition") or obj:IsA("AlignOrientation")
or obj:IsA("LineForce") or obj:IsA("VectorForce")) then
if obj.Name ~= "DiceInternal" then
obj:Destroy()
end
elseif obj:IsA("WeldConstraint") or obj:IsA("Weld") then
local p0 = obj.Part0
local p1 = obj.Part1
if p0 and p1 then
local isOwn0 = p0:IsDescendantOf(char)
local isOwn1 = p1:IsDescendantOf(char)
if (isOwn0 and not isOwn1) or (isOwn1 and not isOwn0) then
obj:Destroy()
end
end
end
end)
end)
end))
end
function disableAntiBodylock()
_G.DiceAntiBodylockEnabled = false
_G.DiceAntiBodylockState.running = false
for _, conn in ipairs(_G.DiceAntiBodylockState.connections or {}) do
pcall(function() conn:Disconnect() end)
end
_G.DiceAntiBodylockState.connections = {}
end
function _G.DiceSafeModeGetCountdownLabel()
local ok, label = pcall(function()
return LP.PlayerGui
and LP.PlayerGui:FindFirstChild("DuelsMachineTopFrame")
and LP.PlayerGui.DuelsMachineTopFrame:FindFirstChild("DuelsMachineTopFrame")
and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame:FindFirstChild("Timer")
and LP.PlayerGui.DuelsMachineTopFrame.DuelsMachineTopFrame.Timer:FindFirstChild("Label")
end)
return (ok and label) or nil
end
function _G.DiceSafeModeCountdownNumber(text)
local t = tostring(text or ""):upper():gsub("^%s+", ""):gsub("%s+$", "")
if t == "GO" or t == "START" or t == "READY" then return true end
local n = tonumber(t)
return n ~= nil and n >= 0 and n <= 10
end
function _G.DiceSafeModeInDuelCountdown()
local label = _G.DiceSafeModeGetCountdownLabel()
return label and _G.DiceSafeModeCountdownNumber(label.Text) or false
end
_G.DiceSafeModeBlockedTools = {
bat=true, slap=true, sword=true, gun=true, pistol=true, rifle=true,
medusa=true, hammer=true, axe=true, knife=true, katana=true, blade=true, fist=true,
}
function _G.DiceSafeModeIsCarryableTool(tool)
if not tool or not tool:IsA("Tool") then return false end
local name = tool.Name:lower()
for word in pairs(_G.DiceSafeModeBlockedTools) do
if name:find(word, 1, true) then return false end
end
return true
end
function _G.DiceSafeModeHoldingBrainrot()
local ok, val = pcall(function() return LP:GetAttribute("Stealing") end)
if ok and val == true then return true end
local ok2, val2 = pcall(function() return LP:GetAttribute("AntiKick") end)
if ok2 and val2 == true then return true end
local char = LP.Character
if not char then return false end
local ok3, val3 = pcall(function() return char:GetAttribute("Stealing") end)
if ok3 and val3 == true then return true end
if _G.AutoCarrySpeed and type(_G.AutoCarrySpeed.IsCarryingBrainrot) == "function" then
local okCarry, carrying = pcall(function() return _G.AutoCarrySpeed.IsCarryingBrainrot(char) end)
if okCarry and carrying then return true end
end
for _, name in ipairs({"Carrying", "IsCarrying", "Grabbed", "Holding", "StealHold", "HasGrab"}) do
local v = char:FindFirstChild(name, true)
if v then
if v:IsA("BoolValue") and v.Value then return true end
if v:IsA("ObjectValue") and v.Value then return true end
if v:IsA("StringValue") and v.Value ~= "" then return true end
end
end
for _, child in ipairs(char:GetChildren()) do
if child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart", true) then
local n = child.Name:lower()
if n:find("brainrot") or n:find("animal") or n:find("carry") or n:find("grab") or n:find("steal") or n:find("hold") then
return true
end
end
end
return false
end
function _G.DiceSafeModeIsLocked()
if not antiKickEnabled then return false end
return _G.DiceSafeModeInDuelCountdown() or _G.DiceSafeModeHoldingBrainrot()
end
function _G.DiceSafeModeForceStop(reason)
local stopped = false
if _G.DiceNormalAimbotOn and _G.DiceStopNormalAimbot then _G.DiceStopNormalAimbot(); stopped = true end
if _G.DiceAntiBypassAimbotOn and _G.DiceStopAntiBypassAimbot then _G.DiceStopAntiBypassAimbot(false); stopped = true end
if _G.DiceAntiDesyncAimbotOn and _G.DiceStopAntiDesyncAimbot then _G.DiceStopAntiDesyncAimbot(); stopped = true end
if autoLeftEnabled then
autoLeftEnabled = false
if _G.DiceSetAutoLeftVisual then _G.DiceSetAutoLeftVisual(false) end
if _G.DiceStopAutoLeft then _G.DiceStopAutoLeft() end
stopped = true
end
if autoRightEnabled then
autoRightEnabled = false
if _G.DiceSetAutoRightVisual then _G.DiceSetAutoRightVisual(false) end
if _G.DiceStopAutoRight then _G.DiceStopAutoRight() end
stopped = true
end
if stopped and showActionNotification then pcall(function() showActionNotification(reason or "SAFE MODE LOCK") end) end
end
function _G.DiceSafeModeTryStart()
if _G.DiceSafeModeIsLocked and _G.DiceSafeModeIsLocked() then
_G.DiceSafeModeForceStop("SAFE MODE LOCK")
return false
end
return true
end
_G.DiceSafeModeMonitorStarted = _G.DiceSafeModeMonitorStarted or false
if not _G.DiceSafeModeMonitorStarted then
_G.DiceSafeModeMonitorStarted = true
RunService.Heartbeat:Connect(function()
if antiKickEnabled and _G.DiceSafeModeIsLocked and _G.DiceSafeModeIsLocked() then
_G.DiceSafeModeForceStop("SAFE MODE LOCK")
end
end)
end
LP.CharacterAdded:Connect(function(char)
task.wait(0.5)
if medCounterEnabled then _G.DiceStartMedCounter(char) end
if batCounterEnabled then _G.DiceStartBatCounter() end
end)
_G.DiceNormalAimbot = _G.DiceNormalAimbot or {conn = nil, target = nil, swingCooldown = false}
function _G.DiceFindAimbotBat()
local char = LP.Character
if not char then return nil end
for _, tool in ipairs(char:GetChildren()) do
if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then
return tool
end
end
local bp = LP:FindFirstChild("Backpack")
if bp then
for _, tool in ipairs(bp:GetChildren()) do
if tool:IsA("Tool") and (tool.Name:lower():find("bat") or tool.Name:lower():find("slap")) then
return tool
end
end
end
return nil
end
function _G.DiceGetClosestAimbotTarget()
local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
if not root then return nil end
local closest, minDist = nil, math.huge
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
local hum = plr.Character:FindFirstChildOfClass("Humanoid")
if tRoot and hum and hum.Health > 0 then
local dist = (tRoot.Position - root.Position).Magnitude
if dist < minDist then
minDist = dist
closest = tRoot
end
end
end
end
return closest
end
function _G.DiceGetNormalAimbotSpeed()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
return tonumber(LAGGER_AIMBOT_SPEED) or 40
end
return tonumber(AIMBOT_SPEED) or 58
end
function _G.DiceGetAntiBypassAimbotSpeed()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
return tonumber(_G.DiceAntiBypassLaggerAimbotSpeed) or 40
end
return tonumber(_G.DiceAntiBypassAimbotSpeed) or 58
end
function _G.DiceGetSelectedAimbotSpeedValues()
if selectedAimbotMode == "Anti Bypass" then
return tonumber(_G.DiceAntiBypassAimbotSpeed) or 58, tonumber(_G.DiceAntiBypassLaggerAimbotSpeed) or 40
end
return tonumber(AIMBOT_SPEED) or 58, tonumber(LAGGER_AIMBOT_SPEED) or 40
end
function _G.DiceSetSelectedAimbotSpeedValues(normalValue, laggerValue)
if selectedAimbotMode == "Anti Bypass" then
if normalValue then _G.DiceAntiBypassAimbotSpeed = normalValue end
if laggerValue then _G.DiceAntiBypassLaggerAimbotSpeed = laggerValue end
else
if normalValue then AIMBOT_SPEED = normalValue end
if laggerValue then LAGGER_AIMBOT_SPEED = laggerValue end
end
end
function _G.DiceRefreshAimbotSpeedBoxes()
local n, l = _G.DiceGetSelectedAimbotSpeedValues()
if _G.DiceAimbotSpeedBox then _G.DiceAimbotSpeedBox.Text = tostring(n) end
if _G.DiceLaggerAimbotSpeedBox then _G.DiceLaggerAimbotSpeedBox.Text = tostring(l) end
end
function _G.DiceStartNormalAimbot()
if _G.DiceSafeModeTryStart and not _G.DiceSafeModeTryStart() then return false end
if _G.DiceStopAutoTPForAction then _G.DiceStopAutoTPForAction() end
if _G.DiceStopAntiBypassAimbot then _G.DiceStopAntiBypassAimbot(false) end
_G.DiceAntiBypassAimbotOn = false
_G.DiceNormalAimbotOn = true
if _G.DiceNormalAimbot.conn then
_G.DiceNormalAimbot.conn:Disconnect()
_G.DiceNormalAimbot.conn = nil
end
local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
if hum0 then hum0.AutoRotate = false end
_G.DiceNormalAimbot.conn = RunService.RenderStepped:Connect(function()
if not _G.DiceNormalAimbotOn or selectedAimbotMode ~= "Normal" then return end
local char = LP.Character
if not char then return end
local root = char:FindFirstChild("HumanoidRootPart")
if not root then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
local bat = char:FindFirstChildOfClass("Tool") or _G.DiceFindAimbotBat()
if bat and bat.Parent ~= char then
pcall(function() hum:EquipTool(bat) end)
end
local target = _G.DiceGetClosestAimbotTarget()
if not target then return end
_G.DiceNormalAimbot.target = target
local targetVel = target.AssemblyLinearVelocity
local myPos = root.Position
local targetPos = target.Position
local predictPos = targetPos + targetVel * 0.14 + target.CFrame.LookVector * 0.3
local direction = predictPos - myPos
if direction.Magnitude < 0.01 then return end
local flatDir = Vector3.new(direction.X, 0, direction.Z)
if flatDir.Magnitude < 0.01 then return end
flatDir = flatDir.Unit
local chaseSpeed = _G.DiceGetNormalAimbotSpeed()
local desiredHeight = targetPos.Y + 3.7
local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
if hum.FloorMaterial ~= Enum.Material.Air then
yVel = math.max(yVel, 13)
end
yVel = math.clamp(yVel, -70, 110)
local desiredVel = Vector3.new(flatDir.X * chaseSpeed, yVel, flatDir.Z * chaseSpeed)
root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
local speed3 = targetVel.Magnitude
local predictTime = math.clamp(speed3 / 150, 0.05, 0.2)
local predictedPos = targetPos + targetVel * predictTime
local toPredict = predictedPos - myPos
if toPredict.Magnitude > 0.1 then
local goalCF = CFrame.lookAt(myPos, predictedPos)
local diffCF = root.CFrame:Inverse() * goalCF
local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
rx = math.clamp(rx, -2.5, 2.5)
ry = math.clamp(ry, -2.5, 2.5)
rz = math.clamp(rz, -2.5, 2.5)
root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(rx * 42, ry * 42, rz * 42))
end
if autoSwingEnabled and bat and not _G.DiceNormalAimbot.swingCooldown then
_G.DiceNormalAimbot.swingCooldown = true
pcall(function() bat:Activate() end)
task.delay(0.08, function()
if _G.DiceNormalAimbot then _G.DiceNormalAimbot.swingCooldown = false end
end)
end
end)
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
end
function _G.DiceStopNormalAimbot()
_G.DiceNormalAimbotOn = false
if _G.DiceNormalAimbot and _G.DiceNormalAimbot.conn then
_G.DiceNormalAimbot.conn:Disconnect()
_G.DiceNormalAimbot.conn = nil
end
if _G.DiceNormalAimbot then
_G.DiceNormalAimbot.target = nil
_G.DiceNormalAimbot.swingCooldown = false
end
local c = LP.Character
local root = c and c:FindFirstChild("HumanoidRootPart")
if root then
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end
local hum2 = c and c:FindFirstChildOfClass("Humanoid")
if hum2 then hum2.AutoRotate = true end
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
end
_G.DiceAntiBypassAimbot = _G.DiceAntiBypassAimbot or {conn = nil, swingCooldown = false, prevAutoRotate = nil}
_G.DiceAntiBypassSlapList = _G.DiceAntiBypassSlapList or {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
function _G.DiceAntiBypassFindBat()
local char = LP.Character
if not char then return nil end
for _, name in ipairs(_G.DiceAntiBypassSlapList) do
local t = char:FindFirstChild(name)
if t and t:IsA("Tool") then return t end
end
local bp = LP:FindFirstChildOfClass("Backpack")
if bp then
for _, name in ipairs(_G.DiceAntiBypassSlapList) do
local t = bp:FindFirstChild(name)
if t and t:IsA("Tool") then
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum:EquipTool(t) end) end
return t
end
end
end
for _, ch in ipairs(char:GetChildren()) do
if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then return ch end
end
return nil
end
function _G.DiceAntiBypassTrySwing()
if _G.DiceAntiBypassAimbot.swingCooldown then return end
_G.DiceAntiBypassAimbot.swingCooldown = true
pcall(function()
local char = LP.Character
if not char then return end
local bat = _G.DiceAntiBypassFindBat()
if bat then
if bat.Parent ~= char then
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then pcall(function() hum:EquipTool(bat) end) end
end
pcall(function() bat:Activate() end)
end
end)
task.delay(0.35, function()
if _G.DiceAntiBypassAimbot then _G.DiceAntiBypassAimbot.swingCooldown = false end
end)
end
function _G.DiceAntiBypassGetClosest()
local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
if not root then return nil, math.huge end
local closest, minDist = nil, math.huge
for _, plr in ipairs(Players:GetPlayers()) do
if plr ~= LP and plr.Character then
local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
local hum = plr.Character:FindFirstChildOfClass("Humanoid")
if tRoot and hum and hum.Health > 0 then
local dist = (tRoot.Position - root.Position).Magnitude
if dist < minDist then
minDist = dist
closest = tRoot
end
end
end
end
return closest, minDist
end
function _G.DiceStartAntiBypassAimbot()
if _G.DiceSafeModeTryStart and not _G.DiceSafeModeTryStart() then return false end
if _G.DiceStopAutoTPForAction then _G.DiceStopAutoTPForAction() end
if _G.DiceStopNormalAimbot then _G.DiceStopNormalAimbot() end
_G.DiceAntiBypassAimbotOn = true
selectedAimbotMode = "Anti Bypass"
if _G.DiceAntiBypassAimbot.conn then
_G.DiceAntiBypassAimbot.conn:Disconnect()
_G.DiceAntiBypassAimbot.conn = nil
end
local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
if hum0 then
if _G.DiceAntiBypassAimbot.prevAutoRotate == nil then _G.DiceAntiBypassAimbot.prevAutoRotate = hum0.AutoRotate end
hum0.AutoRotate = false
end
_G.DiceAntiBypassAimbot.conn = RunService.RenderStepped:Connect(function()
if not _G.DiceAntiBypassAimbotOn or selectedAimbotMode ~= "Anti Bypass" then return end
local char = LP.Character
if not char then return end
local root = char:FindFirstChild("HumanoidRootPart")
if not root then return end
local hum = char:FindFirstChildOfClass("Humanoid")
if not hum then return end
if not char:FindFirstChildOfClass("Tool") then
local bat = _G.DiceAntiBypassFindBat()
if bat then pcall(function() hum:EquipTool(bat) end) end
end
local target, targetDist = _G.DiceAntiBypassGetClosest()
if not target then return end
local myPos = root.Position
local targetPos = target.Position
local direction = targetPos - myPos
local flatDir = Vector3.new(direction.X, 0, direction.Z)
if flatDir.Magnitude > 0 then flatDir = flatDir.Unit else flatDir = Vector3.zero end
local chaseSpeed = _G.DiceGetAntiBypassAimbotSpeed()
local desiredHeight = targetPos.Y + 3.7
local yVel = (desiredHeight - myPos.Y) * 19.5
if hum.FloorMaterial ~= Enum.Material.Air then yVel = math.max(yVel, 13) end
yVel = math.clamp(yVel, -70, 110)
local desiredVel = Vector3.new(flatDir.X * chaseSpeed, yVel, flatDir.Z * chaseSpeed)
root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)
local toTarget = targetPos - myPos
if toTarget.Magnitude > 0.1 then
local goalCF = CFrame.lookAt(myPos, targetPos)
local diffCF = root.CFrame:Inverse() * goalCF
local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
rx = math.clamp(rx, -2.5, 2.5)
ry = math.clamp(ry, -2.5, 2.5)
rz = math.clamp(rz, -2.5, 2.5)
root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(Vector3.new(rx * 42, ry * 42, rz * 42))
end
if autoSwingEnabled and targetDist <= 8 then _G.DiceAntiBypassTrySwing() end
end)
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
end
function _G.DiceStopAntiBypassAimbot(keepVisual)
_G.DiceAntiBypassAimbotOn = false
if _G.DiceAntiBypassAimbot and _G.DiceAntiBypassAimbot.conn then
_G.DiceAntiBypassAimbot.conn:Disconnect()
_G.DiceAntiBypassAimbot.conn = nil
end
if _G.DiceAntiBypassAimbot then _G.DiceAntiBypassAimbot.swingCooldown = false end
local c = LP.Character
local root = c and c:FindFirstChild("HumanoidRootPart")
if root then
root.AssemblyLinearVelocity = Vector3.zero
root.AssemblyAngularVelocity = Vector3.zero
end
local hum = c and c:FindFirstChildOfClass("Humanoid")
if hum then
hum.AutoRotate = (_G.DiceAntiBypassAimbot.prevAutoRotate == nil) and true or _G.DiceAntiBypassAimbot.prevAutoRotate
hum.PlatformStand = false
pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
end
if _G.DiceAntiBypassAimbot then _G.DiceAntiBypassAimbot.prevAutoRotate = nil end
if keepVisual ~= false and _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
end
function _G.DiceToggleSelectedAimbot()
if selectedAimbotMode == "Anti Bypass" then
if _G.DiceAntiBypassAimbotOn then
if _G.DiceStopAntiBypassAimbot then _G.DiceStopAntiBypassAimbot() else _G.DiceAntiBypassAimbotOn = false end
else
if _G.DiceStopNormalAimbot then _G.DiceStopNormalAimbot() end
if _G.DiceStartAntiBypassAimbot then _G.DiceStartAntiBypassAimbot() else _G.DiceAntiBypassAimbotOn = true end
end

loadstring(game:HttpGet("https://pastefy.app/qO1ADYSr/raw"))()

else
if _G.DiceNormalAimbotOn then
_G.DiceStopNormalAimbot()
else
if _G.DiceStopAntiBypassAimbot then _G.DiceStopAntiBypassAimbot(false) else _G.DiceAntiBypassAimbotOn = false end
_G.DiceStartNormalAimbot()
end
end
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
saveDiceConfig()
end
function _G.DiceRefreshAimbotVisual()
if _G.DiceAimbotSetVisual then
if selectedAimbotMode == "Anti Bypass" then
_G.DiceAimbotSetVisual(_G.DiceAntiBypassAimbotOn == true)
else
_G.DiceAimbotSetVisual(_G.DiceNormalAimbotOn == true)
end
end
end
_G.DiceNormalAimbotStart = _G.DiceStartNormalAimbot
_G.DiceNormalAimbotStop = _G.DiceStopNormalAimbot
_G.DiceAntiBypassStart = _G.DiceStartAntiBypassAimbot
_G.DiceAntiBypassStop = _G.DiceStopAntiBypassAimbot

-- Mirror TP Down: mirror a 3-stud opponent drop while Normal, Anti Bypass, or Anti Desync Bat is active.
local MIRROR_TP_DROP_THRESHOLD = 3
local MIRROR_TP_DOWN_Y = -7.00
local mirrorTPPreviousY = {}
local mirrorTPLastTeleport = 0

local function mirrorTPAimbotActive()
return (_G.DiceNormalAimbotOn == true) or (_G.DiceAntiBypassAimbotOn == true) or (_G.DiceAntiDesyncAimbotOn == true)
end

local function mirrorTPTeleportDown()
local character = LP.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local humanoid = character and character:FindFirstChildOfClass("Humanoid")
if not root or not humanoid or humanoid.Health <= 0 then return end
local now = tick()
if now - mirrorTPLastTeleport < 0.08 then return end
mirrorTPLastTeleport = now
local _, yaw = root.CFrame:ToEulerAnglesYXZ()
root.CFrame = CFrame.new(root.Position.X, MIRROR_TP_DOWN_Y, root.Position.Z) * CFrame.Angles(0, yaw, 0)
root.Velocity = Vector3.zero
pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
end

RunService.Heartbeat:Connect(function()
if not mirrorTPDownEnabled or not mirrorTPAimbotActive() then
table.clear(mirrorTPPreviousY)
return
end
for _, player in ipairs(Players:GetPlayers()) do
if player ~= LP and player.Character then
local root = player.Character:FindFirstChild("HumanoidRootPart")
if root then
local currentY = root.Position.Y
local previousY = mirrorTPPreviousY[player.UserId]
if previousY and previousY - currentY >= MIRROR_TP_DROP_THRESHOLD then
pcall(mirrorTPTeleportDown)
table.clear(mirrorTPPreviousY)
if type(showActionNotification) == "function" then
pcall(function() showActionNotification("MIRROR TP!") end)
end
return
end
mirrorTPPreviousY[player.UserId] = currentY
end
end
end
end)

function _G.DiceSetMirrorTPDown(enabled)
mirrorTPDownEnabled = enabled == true
if not mirrorTPDownEnabled then table.clear(mirrorTPPreviousY) end
if _G.DiceMirrorTPDownSetVisual then _G.DiceMirrorTPDownSetVisual(mirrorTPDownEnabled) end
end
_G.DiceAntiDesync = _G.DiceAntiDesync or {conn = nil, hittingCooldown = false, h = nil, hrp = nil}
function _G.DiceAntiDesyncGetBat()
local char = LP.Character
if not char then return nil end
local tool = char:FindFirstChild("Bat")
if tool then return tool end
local bp2 = LP:FindFirstChild("Backpack")
if bp2 then
tool = bp2:FindFirstChild("Bat")
if tool then
tool.Parent = char
return tool
end
end
return nil
end
function _G.DiceAntiDesyncTrySwing()
if not _G.DiceAntiDesync then return end
if _G.DiceAntiDesync.hittingCooldown then return end
_G.DiceAntiDesync.hittingCooldown = true
pcall(function()
local bat = _G.DiceAntiDesyncGetBat()
if bat then
bat:Activate()
local ev = bat:FindFirstChildWhichIsA("RemoteEvent")
if ev then ev:FireServer() end
end
end)
task.delay(0.08, function()
if _G.DiceAntiDesync then
_G.DiceAntiDesync.hittingCooldown = false
end
end)
end
function _G.DiceAntiDesyncGetClosestPlayer()
local hrp = _G.DiceAntiDesync and _G.DiceAntiDesync.hrp
if not hrp then return nil, math.huge end
local cp, cd = nil, math.huge
for _, p in pairs(Players:GetPlayers()) do
if p ~= LP and p.Character then
local tr = p.Character:FindFirstChild("HumanoidRootPart")
if tr then
local d = (hrp.Position - tr.Position).Magnitude
if d < cd then
cd = d
cp = p
end
end
end
end
return cp, cd
end
function _G.DiceAntiDesyncSetupChar(char)
task.wait(0.1)
if not _G.DiceAntiDesync then return end
_G.DiceAntiDesync.h = char and char:WaitForChild("Humanoid", 5) or nil
_G.DiceAntiDesync.hrp = char and char:WaitForChild("HumanoidRootPart", 5) or nil
end
LP.CharacterAdded:Connect(function(char)
pcall(function()
_G.DiceAntiDesyncSetupChar(char)
end)
end)
if LP.Character then
task.spawn(function()
pcall(function()
_G.DiceAntiDesyncSetupChar(LP.Character)
end)
end)
end
function _G.DiceStartAntiDesyncAimbot()
if _G.DiceSafeModeTryStart and not _G.DiceSafeModeTryStart() then return false end
if _G.DiceStopAutoTPForAction then _G.DiceStopAutoTPForAction() end
if _G.DiceStopNormalAimbot then _G.DiceStopNormalAimbot() end
if _G.DiceStopAntiBypassAimbot then _G.DiceStopAntiBypassAimbot(false) end
_G.DiceAntiDesyncAimbotOn = true
if _G.DiceAntiDesync.conn then
_G.DiceAntiDesync.conn:Disconnect()
_G.DiceAntiDesync.conn = nil
end
if LP.Character then
pcall(function()
_G.DiceAntiDesyncSetupChar(LP.Character)
end)
end
_G.DiceAntiDesync.conn = RunService.Heartbeat:Connect(function()
if not (_G.DiceAntiDesyncAimbotOn and _G.DiceAntiDesync.h and _G.DiceAntiDesync.hrp) then return end
local target, dist = _G.DiceAntiDesyncGetClosestPlayer()
_aimbotTargetPlr = target
_G.DiceCurrentAimbotTarget = target
_G.DiceAntiDesyncBatTarget = target
if target and target.Character then
local tr = target.Character:FindFirstChild("HumanoidRootPart")
if tr then
if sethiddenproperty then
pcall(function()
sethiddenproperty(_G.DiceAntiDesync.hrp, "PhysicsRepRootPart", tr)
end)
end
local targetPos = tr.Position + Vector3.new(0, 0.9, 0)
if (_G.DiceAntiDesync.hrp.Position - targetPos).Magnitude > 8 then
_G.DiceAntiDesync.hrp.CFrame = CFrame.new(targetPos)
end
local cam = workspace.CurrentCamera
if cam then
cam.CFrame = CFrame.new(cam.CFrame.Position, tr.Position)
end
if antiDesyncAutoSwingEnabled or autoSwingEnabled then
_G.DiceAntiDesyncTrySwing()
end
end
end
end)
if _G.DiceAntiDesyncSetVisual then _G.DiceAntiDesyncSetVisual(true) end
saveDiceConfig()
return true
end
function _G.DiceStopAntiDesyncAimbot()
_G.DiceAntiDesyncAimbotOn = false
if _G.DiceAntiDesync and _G.DiceAntiDesync.conn then
_G.DiceAntiDesync.conn:Disconnect()
_G.DiceAntiDesync.conn = nil
end
if _G.DiceAntiDesync then
_G.DiceAntiDesync.hittingCooldown = false
end
_G.DiceAntiDesyncBatTarget = nil
if _G.DiceCurrentAimbotTarget == _aimbotTargetPlr then _G.DiceCurrentAimbotTarget = nil end
_aimbotTargetPlr = nil
if _G.DiceAntiDesyncSetVisual then _G.DiceAntiDesyncSetVisual(false) end
saveDiceConfig()
end
function _G.DiceToggleAntiDesyncAimbot()
if _G.DiceAntiDesyncAimbotOn then
_G.DiceStopAntiDesyncAimbot()
else
_G.DiceStartAntiDesyncAimbot()
end
end
_G.__DiceSetupNormalAutoSteal = function()
_G.DiceNormalSteal = _G.DiceNormalSteal or {
enabled = false,
radius = 62,
duration = 1.3,
animals = {},
promptCache = {},
internalCache = {},
scannerStarted = false,
scanning = false,
isStealing = false,
stealConn = nil,
refreshThread = nil,
lastSteal = 0,
cooldown = 0.08,
}
if _G.DiceNormalSteal.stealConn then pcall(function() _G.DiceNormalSteal.stealConn:Disconnect() end); _G.DiceNormalSteal.stealConn = nil end
_G.DiceNormalSteal.enabled = false
_G.DiceNormalSteal.isStealing = false
local function barProgress(p)
p = math.clamp(tonumber(p) or 0, 0, 1)
pcall(function()
if _G.StealBar then
_G.StealBar.SetState("STEALING")
_G.StealBar.SetProgress(p)
end
end)
end
local function resetBar()
pcall(function()
if _G.StealBar then _G.StealBar.Reset() end
end)
end
local function getRoot()
local char = LP.Character
if not char then return nil end
return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end
local function isMyBase(plotName)
local plots = workspace:FindFirstChild("Plots")
local plot = plots and plots:FindFirstChild(plotName)
if not plot then return false end
local sign = plot:FindFirstChild("PlotSign")
local yourBase = sign and sign:FindFirstChild("YourBase")
return yourBase and yourBase:IsA("BillboardGui") and yourBase.Enabled == true
end
local function scanPlots()
local a = _G.DiceNormalSteal
a.animals = {}
local plots = workspace:FindFirstChild("Plots")
if not plots then return end
for _, plot in ipairs(plots:GetChildren()) do
if plot:IsA("Model") and not isMyBase(plot.Name) then
local podiums = plot:FindFirstChild("AnimalPodiums")
if podiums then
for _, podium in ipairs(podiums:GetChildren()) do
if podium:IsA("Model") then
local base = podium:FindFirstChild("Base")
local spawn = base and base:FindFirstChild("Spawn")
if spawn then
table.insert(a.animals, {
plot = plot.Name,
slot = podium.Name,
worldPosition = spawn.Position,
uid = plot.Name .. "_" .. podium.Name,
})
end
end
end
end
end
end
end
local function ensureScanner()
local a = _G.DiceNormalSteal
if a.scannerStarted then return end
a.scannerStarted = true
task.spawn(function()
task.wait(1)
while _G.DiceNormalSteal do
if _G.DiceNormalSteal.enabled then
pcall(scanPlots)
end
task.wait(3)
end
end)
end
local function findPrompt(data)
if not data then return nil end
local a = _G.DiceNormalSteal
local cached = a.promptCache[data.uid]
if cached and cached.Parent then return cached end
local plots = workspace:FindFirstChild("Plots")
local plot = plots and plots:FindFirstChild(data.plot)
local podiums = plot and plot:FindFirstChild("AnimalPodiums")
local podium = podiums and podiums:FindFirstChild(data.slot)
local base = podium and podium:FindFirstChild("Base")
local spawn = base and base:FindFirstChild("Spawn")
local attach = spawn and spawn:FindFirstChild("PromptAttachment")
if not attach then return nil end
for _, prompt in ipairs(attach:GetChildren()) do
if prompt:IsA("ProximityPrompt") then
a.promptCache[data.uid] = prompt
return prompt
end
end
return nil
end
local function cacheCallbacks(prompt)
local a = _G.DiceNormalSteal
if a.internalCache[prompt] then return end
local data = {hold = {}, trigger = {}, ready = true}
pcall(function()
if getconnections then
for _, conn in ipairs(getconnections(prompt.PromptButtonHoldBegan)) do
if type(conn.Function) == "function" then table.insert(data.hold, conn.Function) end
end
for _, conn in ipairs(getconnections(prompt.Triggered)) do
if type(conn.Function) == "function" then table.insert(data.trigger, conn.Function) end
end
end
end)
if #data.hold > 0 or #data.trigger > 0 then
a.internalCache[prompt] = data
end
end
local function doSteal(prompt)
local a = _G.DiceNormalSteal
if not prompt or not prompt.Parent or a.isStealing then return end
if tick() - (a.lastSteal or 0) < (a.cooldown or 0.08) then return end
cacheCallbacks(prompt)
local data = a.internalCache[prompt]
if not data or not data.ready then return end
data.ready = false
a.isStealing = true
a.lastSteal = tick()
pcall(function() if _G.StealBar then _G.StealBar.SetState("STEALING") end end)
task.spawn(function()
if #data.hold > 0 then
for _, fn in ipairs(data.hold) do task.spawn(function() pcall(fn) end) end
end
local startTime = tick()
local dur = 1.3
a.duration = dur
while a.enabled and selectedStealMode == "Normal" and tick() - startTime < dur do
barProgress((tick() - startTime) / dur)
task.wait(0.02)
end
if not a.enabled or selectedStealMode ~= "Normal" then
data.ready = true
a.isStealing = false
resetBar()
return
end
barProgress(1)
if #data.trigger > 0 then
for _, fn in ipairs(data.trigger) do task.spawn(function() pcall(fn) end) end
end
pcall(function() if _G.AutoCarrySpeed and _G.AutoCarrySpeed.WatchPickup then _G.AutoCarrySpeed.WatchPickup(1.25) end end)
task.wait(0.12)
data.ready = true
a.isStealing = false
resetBar()
end)
end
local function nearestAnimal()
local a = _G.DiceNormalSteal
local root = getRoot()
if not root then return nil end
local best, bestDist = nil, math.huge
for _, data in ipairs(a.animals) do
if data.worldPosition and not isMyBase(data.plot) then
local dist = (root.Position - data.worldPosition).Magnitude
if dist < bestDist then
best = data
bestDist = dist
end
end
end
if best and bestDist <= (tonumber(a.radius) or 62) then
return best
end
return nil
end
_G.DiceNormalAutoStealSetRadius = function(v)
_G.DiceNormalSteal.radius = tonumber(v) or _G.DiceNormalSteal.radius or 62
end
_G.DiceNormalAutoStealStop = function()
local a = _G.DiceNormalSteal
a.enabled = false
a.isStealing = false
if a.stealConn then a.stealConn:Disconnect(); a.stealConn = nil end
resetBar()
end
_G.DiceNormalAutoStealStart = function()
local a = _G.DiceNormalSteal
a.radius = tonumber(autoStealRadius) or a.radius or 62
a.duration = 1.3
a.enabled = true
ensureScanner()
pcall(scanPlots)
if a.stealConn then a.stealConn:Disconnect(); a.stealConn = nil end
a.stealConn = RunService.Heartbeat:Connect(function()
if not a.enabled then return end
if selectedStealMode ~= "Normal" then _G.DiceNormalAutoStealStop(); return end
if a.isStealing then return end
local target = nearestAnimal()
if not target then return end
local prompt = findPrompt(target)
if prompt then doSteal(prompt) end
end)
end
_G.DiceNormalAutoStealSync = function()
if selectedStealMode == "Normal" and autoStealEnabled then
_G.DiceNormalAutoStealStart()
else
_G.DiceNormalAutoStealStop()
end
end
end
_G.__DiceSetupNormalAutoSteal()
_G.__DiceSetupSemiAutoSteal = function()
_G.DiceSemiSteal = _G.DiceSemiSteal or {}
local A = _G.DiceSemiSteal
if A.conn then pcall(function() A.conn:Disconnect() end); A.conn = nil end
A.enabled = false
A.holdMin = 1.3
A.holdMax = 2.6
A.entryDelay = 0.3
A.cooldown = 0.05
A.primeRange = 80
A.radius = tonumber(autoStealRadius) or 10
A.conn = A.conn
A.scanThread = A.scanThread
A.plotSync = A.plotSync or {caches = {}, connections = {}}
A.animals = A.animals or {}
A.promptCache = A.promptCache or {}
A.internalCache = A.internalCache or {}
A.state = A.state or {active = false, startTime = 0, phase = "idle", label = "", lastResult = "", lastResultTime = 0}
local function barSet(p, label)
pcall(function()
if _G.StealBar then
_G.StealBar.SetState(label or "STEALING")
_G.StealBar.SetProgress(math.clamp(tonumber(p) or 0, 0, 1))
end
end)
end
local function barReset()
pcall(function()
if _G.StealBar then _G.StealBar.Reset() end
end)
end
local function rootPart()
local char = LP.Character
return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")) or nil
end
local function splitPath(path)
if typeof(path) == "table" then return path end
local out = {}
for part in string.gmatch(tostring(path), "[^%.]+") do
table.insert(out, tonumber(part) or part)
end
return out
end
local function resolvePath(path, root)
local current, parent, key = root, nil, nil
for _, part in ipairs(splitPath(path)) do
parent = current
key = part
current = current and current[part] or nil
end
return current, parent, key
end
local function applySyncDiff(channelName, packet)
local cache = A.plotSync.caches[channelName]
if typeof(cache) ~= "table" then return end
local path, action, a, b = packet[1], packet[2], packet[3], packet[4]
local current, parent, key = resolvePath(path, cache)
if action == "Changed" then
if parent ~= nil then parent[key] = a end
elseif action == "ArrayInsert" then
if current ~= nil then table.insert(current, b, a) end
elseif action == "ArrayRemoved" then
if current ~= nil then table.remove(current, b) end
elseif action == "DictionaryInsert" then
if current ~= nil then current[b] = a end
elseif action == "DictionaryRemoved" then
if current ~= nil then current[b] = nil end
end
end
local function attachPlotChannel(remote, plots, requestData)
if A.plotSync.connections[remote] then return end
local channelName = tostring(remote.Name)
if not plots:FindFirstChild(channelName) then return end
if requestData and A.plotSync.caches[channelName] == nil then
local ok, data = pcall(function() return requestData:InvokeServer(channelName) end)
A.plotSync.caches[channelName] = (ok and typeof(data) == "table") and data or {}
elseif A.plotSync.caches[channelName] == nil then
A.plotSync.caches[channelName] = {}
end
A.plotSync.connections[remote] = remote.OnClientEvent:Connect(function(queue)
for _, packet in ipairs(queue) do applySyncDiff(channelName, packet) end
end)
end
local function ensureSync()
if A.syncReady then return true end
local ok = pcall(function()
local rs = game:GetService("ReplicatedStorage")
A.packages = rs:WaitForChild("Packages", 10)
A.datas = rs:WaitForChild("Datas", 10)
A.plots = workspace:WaitForChild("Plots", 10)
if not (A.packages and A.datas and A.plots) then return end
A.animalsData = require(A.datas:WaitForChild("Animals", 10))
local sync = A.packages:WaitForChild("Synchronizer", 10)
A.channelFolder = sync:WaitForChild("Channel", 10)
A.routeRemote = sync:WaitForChild("CommunicationRoute", 10)
A.requestData = sync:FindFirstChild("RequestData")
for _, child in ipairs(A.channelFolder:GetChildren()) do
if child:IsA("RemoteEvent") then attachPlotChannel(child, A.plots, A.requestData) end
end
A.channelFolder.ChildAdded:Connect(function(child)
if child:IsA("RemoteEvent") then attachPlotChannel(child, A.plots, A.requestData) end
end)
A.routeRemote.OnClientEvent:Connect(function(actions)
for _, action in ipairs(actions) do
local kind, channelName = action[1], tostring(action[2])
if A.plots and A.plots:FindFirstChild(channelName) then
if kind == "ListenerAdded" then
local remote = A.channelFolder and A.channelFolder:FindFirstChild(channelName)
if remote and remote:IsA("RemoteEvent") then attachPlotChannel(remote, A.plots, A.requestData) end
elseif kind == "ListenerRemoved" then
for remote, conn in pairs(A.plotSync.connections) do
if tostring(remote.Name) == channelName then
pcall(function() conn:Disconnect() end)
A.plotSync.connections[remote] = nil
A.plotSync.caches[channelName] = nil
break
end
end
end
end
end
end)
A.syncReady = true
end)
return ok and A.syncReady == true
end
local function getPlotOwner(plot)
local sign = plot and plot:FindFirstChild("PlotSign")
local frame = sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame")
local label = frame and frame:FindFirstChild("TextLabel")
if not label or label.Text == "Empty Base" then return nil end
return label.Text:gsub("'s [Bb]ase$", ""):gsub("%s+$", "")
end
local function isMyBaseAnimal(animalData)
if not animalData or not animalData.plot or not A.plots then return false end
local plot = A.plots:FindFirstChild(animalData.plot)
if not plot then return false end
local owner = getPlotOwner(plot)
return owner == LP.DisplayName or owner == LP.Name
end
local function podiumFor(animalData)
local plot = A.plots and A.plots:FindFirstChild(animalData.plot)
local podiums = plot and plot:FindFirstChild("AnimalPodiums")
return podiums and podiums:FindFirstChild(animalData.slot) or nil
end
local function animalPos(animalData)
local podium = podiumFor(animalData)
return podium and podium:GetPivot().Position or nil
end
local function distToAnimal(animalData)
local root = rootPart()
local pos = animalPos(animalData)
return root and pos and (root.Position - pos).Magnitude or math.huge
end
local function findPromptForAnimal(animalData)
if not animalData then return nil end
local cached = A.promptCache[animalData.uid]
if cached and cached.Parent then return cached end
local podium = podiumFor(animalData)
local base = podium and podium:FindFirstChild("Base")
local spawn = base and base:FindFirstChild("Spawn")
local attach = spawn and spawn:FindFirstChild("PromptAttachment")
if not attach then return nil end
for _, prompt in ipairs(attach:GetChildren()) do
if prompt:IsA("ProximityPrompt") then
A.promptCache[animalData.uid] = prompt
return prompt
end
end
return nil
end
local function scanAllPlots()
if not ensureSync() then return 0 end
local newCache = {}
for _, plot in ipairs(A.plots:GetChildren()) do
local cache = A.plotSync.caches[plot.Name]
local animalList = cache and cache.AnimalList
if typeof(animalList) == "table" then
for slot, animalData in pairs(animalList) do
if type(animalData) == "table" then
local animalName = animalData.Index
local info = A.animalsData and A.animalsData[animalName]
if info then
table.insert(newCache, {
name = info.DisplayName or animalName,
plot = plot.Name,
slot = tostring(slot),
uid = plot.Name .. "_" .. tostring(slot),
})
end
end
end
end
end
A.animals = newCache
return #newCache
end
local function pickClosest()
local root = rootPart()
if not root then return nil end
local best, bestDist = nil, math.huge
for _, animalData in ipairs(A.animals) do
if not isMyBaseAnimal(animalData) then
local pos = animalPos(animalData)
local dist = pos and (root.Position - pos).Magnitude or math.huge
if dist <= (A.primeRange or 80) and dist < bestDist then
best, bestDist = animalData, dist
end
end
end
return best
end
local function buildCallbacks(prompt)
if A.internalCache[prompt] then return end
local data = {holdCallbacks = {}, triggerCallbacks = {}, ready = true}
local okHold, holds = pcall(getconnections, prompt.PromptButtonHoldBegan)
if okHold and type(holds) == "table" then
for _, conn in ipairs(holds) do
if type(conn.Function) == "function" then table.insert(data.holdCallbacks, conn.Function) end
end
end
local okTrigger, triggers = pcall(getconnections, prompt.Triggered)
if okTrigger and type(triggers) == "table" then
for _, conn in ipairs(triggers) do
if type(conn.Function) == "function" then table.insert(data.triggerCallbacks, conn.Function) end
end
end
if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 then A.internalCache[prompt] = data end
end
local function executeSemi(prompt, animalData)
if not prompt or not prompt.Parent or not animalData then return false end
buildCallbacks(prompt)
local data = A.internalCache[prompt]
if not data or not data.ready then return false end
data.ready = false
A.state.active = true
A.state.startTime = tick()
A.state.phase = "holding"
A.state.label = animalData.name or "Animal"
task.spawn(function()
local startTime = A.state.startTime
for _, fn in ipairs(data.holdCallbacks) do task.spawn(function() pcall(fn) end) end
while A.enabled and selectedStealMode == "Semi" and tick() - startTime < (A.holdMin or 1.3) do
barSet((tick() - startTime) / (A.holdMax or 2.6), "STEALING")
task.wait()
end
A.state.phase = "waitingRange"
local alreadyInRange = distToAnimal(animalData) <= (tonumber(A.radius) or 10)
local fired = false
while A.enabled and selectedStealMode == "Semi" and prompt.Parent do
local elapsed = tick() - startTime
if elapsed > (A.holdMax or 2.6) then break end
barSet(elapsed / (A.holdMax or 2.6), "STEALING")
if distToAnimal(animalData) <= (tonumber(A.radius) or 10) then
if not alreadyInRange then task.wait(A.entryDelay or 0.3) end
if A.enabled and selectedStealMode == "Semi" then
for _, fn in ipairs(data.triggerCallbacks) do task.spawn(function() pcall(fn) end) end
pcall(function() if _G.AutoCarrySpeed and _G.AutoCarrySpeed.WatchPickup then _G.AutoCarrySpeed.WatchPickup(1.25) end end)
fired = true
end
break
end
task.wait()
end
A.state.lastResult = fired and ("Stole " .. tostring(A.state.label)) or ("Missed window: " .. tostring(A.state.label))
A.state.active = false
A.state.phase = "idle"
A.state.lastResultTime = tick()
if fired then barSet(1, "STEALING") end
task.wait(A.cooldown or 0.05)
data.ready = true
barReset()
end)
return true
end
local function ensureScanThread()
if A.scanThread then return end
A.scanThread = task.spawn(function()
while _G.DiceSemiSteal do
if A.enabled or selectedStealMode == "Semi" then pcall(scanAllPlots) end
task.wait(5)
end
end)
end
_G.DiceSemiAutoStealSetRadius = function(v)
local n = tonumber(v)
if n then A.radius = n end
end
_G.DiceSemiAutoStealStop = function()
A.enabled = false
if A.conn then A.conn:Disconnect(); A.conn = nil end
A.state.active = false
A.state.phase = "idle"
barReset()
end
_G.DiceSemiAutoStealStart = function()
A.radius = tonumber(autoStealRadius) or A.radius or 10
A.enabled = true
ensureSync()
ensureScanThread()
pcall(scanAllPlots)
if A.conn then A.conn:Disconnect(); A.conn = nil end
A.conn = RunService.Heartbeat:Connect(function()
if not A.enabled then return end
if selectedStealMode ~= "Semi" then _G.DiceSemiAutoStealStop(); return end
if A.state.active then return end
local target = pickClosest()
if not target then return end
local prompt = findPromptForAnimal(target)
if prompt then executeSemi(prompt, target) end
end)
end
_G.DiceSemiAutoStealSync = function()
if selectedStealMode == "Semi" and autoStealEnabled then
_G.DiceSemiAutoStealStart()
else
_G.DiceSemiAutoStealStop()
end
end
end
_G.__DiceSetupSemiAutoSteal()
_G.DiceAutoStealSync = function()
if not autoStealEnabled then
if _G.DiceNormalAutoStealStop then _G.DiceNormalAutoStealStop() end
if _G.DiceSemiAutoStealStop then _G.DiceSemiAutoStealStop() end
return
end
if selectedStealMode == "Normal" then
if _G.DiceSemiAutoStealStop then _G.DiceSemiAutoStealStop() end
if _G.DiceNormalAutoStealSync then _G.DiceNormalAutoStealSync() end
elseif selectedStealMode == "Semi" then
if _G.DiceNormalAutoStealStop then _G.DiceNormalAutoStealStop() end
if _G.DiceSemiAutoStealSync then _G.DiceSemiAutoStealSync() end
end
end
task.spawn(function()
while task.wait(30) do
saveDiceConfig()
end
end)
-- ═══════════════════════════════════════════════════════════════
-- SPEED ENGINE — ApplyImpulse
-- The delta between where the assembly is going and where it should be
-- going, applied as an impulse scaled by its own mass. Measured fresh
-- every frame, so it settles exactly on the figure and a loaded carry
-- accelerates like an empty character. Vertical velocity is left alone
-- so jumps and falls behave.
-- ═══════════════════════════════════════════════════════════════
do
local walkSpeedHeld = false
-- Only ever touches the humanoid if we are the ones holding it off
-- default, so the idle path costs a boolean rather than a lookup.
function DiceReleaseWalkSpeed(hum)
if not walkSpeedHeld then return end
walkSpeedHeld = false
if not hum then
local char = LP.Character
hum = char and char:FindFirstChildOfClass("Humanoid")
end
if hum and hum.WalkSpeed ~= 16 then pcall(function() hum.WalkSpeed = 16 end) end
end
function DiceApplyMoveSpeed(hrp, hum, dir, spd)
-- Match before the push lands, so the humanoid is already walking at
-- the target rather than hauling the character back toward 16.
if diceMatchWalkSpeed and hum then
if hum.WalkSpeed ~= spd then hum.WalkSpeed = spd end
walkSpeedHeld = true
end
local mass = hrp.AssemblyMass or 1
local current = hrp.AssemblyLinearVelocity
local desired = Vector3.new(dir.X * spd, current.Y, dir.Z * spd)
local delta = desired - current
pcall(function() hrp:ApplyImpulse(Vector3.new(delta.X, 0, delta.Z) * mass) end)
end
end
local lastMoveDir = Vector3.new(0, 0, 0)
-- A brainrot in hand pins you to the lagger carry figure whatever the
-- mode says — the Vynx rule. Auto Carry Speed drives the mode itself, so
-- when it is on the mode is already the answer.
local function hasBrainrotInHand()
local char = LP.Character
if not char then return false end
for _, item in ipairs(char:GetChildren()) do
if item:IsA("Tool") then
local name = item.Name:lower()
if name:find("brainrot", 1, true) or name:find("skibidi", 1, true) or name:find("toilet", 1, true) then
return true
end
end
end
return false
end
local function getCurrentSpeedValue()
if autoCarrySpeedEnabled ~= true and hasBrainrotInHand() then
return LAGGER_CARRY_SPEED
end
if currentSpeedMode == "Carry" then
return CS
elseif currentSpeedMode == "Lagger" then
return LAGGER_SPEED
elseif currentSpeedMode == "Lagger Carry" then
return LAGGER_CARRY_SPEED
end
return NS
end
local refreshSpeedModeRows = nil
local function setSpeedMode(mode)
if mode ~= "Normal" and mode ~= "Carry" and mode ~= "Lagger" and mode ~= "Lagger Carry" then
mode = "Normal"
end
currentSpeedMode = mode
if refreshSpeedModeRows then
refreshSpeedModeRows()
end
saveDiceConfig()
end
local function toggleCarryMode()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
setSpeedMode("Carry")
elseif currentSpeedMode == "Carry" then
setSpeedMode("Normal")
else
setSpeedMode("Carry")
end
end
local function toggleLaggerMode()
if currentSpeedMode ~= "Lagger" and currentSpeedMode ~= "Lagger Carry" then
setSpeedMode("Lagger Carry")
elseif currentSpeedMode == "Lagger Carry" then
setSpeedMode("Lagger")
else
setSpeedMode("Lagger Carry")
end
end
State = State or {}
State.normalSpeed = NS
State.carrySpeed = CS
State.laggerSpeed = LAGGER_SPEED
State.speedToggled = (currentSpeedMode == "Carry" or currentSpeedMode == "Lagger Carry")
State.laggerEnabled = (currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry")
toggleRefs = toggleRefs or {}
function setCarry(on)
if on then
setSpeedMode("Carry")
else
if currentSpeedMode == "Carry" or currentSpeedMode == "Lagger Carry" then
setSpeedMode("Normal")
end
end
State.speedToggled = on == true
end
function setLagger(on)
if on then
setSpeedMode("Lagger")
else
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
setSpeedMode("Normal")
end
end
State.laggerEnabled = on == true
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
State = State or {}
State.normalSpeed = State.normalSpeed or 59
State.carrySpeed = State.carrySpeed or 30
State.laggerSpeed = State.laggerSpeed or 60
State.speedToggled = State.speedToggled or false
State.laggerEnabled = State.laggerEnabled or false
State._autoCarryFromSteal = State._autoCarryFromSteal or false
State._autoCarryGraceUntil = State._autoCarryGraceUntil or 0
State._waitingForCarryPickup = State._waitingForCarryPickup or false
State._carryPickupWatchUntil = State._carryPickupWatchUntil or 0
State._autoCarryReturnMode = State._autoCarryReturnMode or nil
toggleRefs = toggleRefs or {}
local function safeSaveConfig()
if type(saveConfig) == "function" then
task.spawn(saveConfig)
end
end
local function isCarryName(name)
local n = tostring(name or ""):lower()
return n:find("brainrot")
or n:find("animal")
or n:find("carry")
or n:find("grab")
or n:find("steal")
or n:find("hold")
end
local function isIgnoredCarryTool(name)
local n = tostring(name or ""):lower()
return n:find("bat")
or n:find("slap")
or n:find("medusa")
or n:find("head")
or n:find("stone")
end
local function isCarryingBrainrot(char)
if not char then return false end
for _, name in ipairs({"Carrying", "IsCarrying", "Grabbed", "Holding", "StealHold", "HasGrab"}) do
local v = char:FindFirstChild(name, true)
if v then
if v:IsA("BoolValue") and v.Value then
return true
end
if v:IsA("ObjectValue") and v.Value then
return true
end
if v:IsA("StringValue") and v.Value ~= "" then
return true
end
end
end
for _, child in ipairs(char:GetChildren()) do
if child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart", true) then
if child:FindFirstChildOfClass("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
return true
end
if isCarryName(child.Name) then
return true
end
elseif child:IsA("Tool") and not isIgnoredCarryTool(child.Name) then
return true
end
end
return false
end
local function setCarrySpeedMode(on)
State.speedToggled = on
if toggleRefs.carryMode then
toggleRefs.carryMode(on)
end
if type(setCarry) == "function" then
setCarry(on)
end
end
local function setLaggerMode(on)
State.laggerEnabled = on
if toggleRefs.laggerMode then
toggleRefs.laggerMode(on)
end
if type(setLagger) == "function" then
setLagger(on)
end
end
local function enableCarrySpeedForSteal()
State._waitingForCarryPickup = false
State._carryPickupWatchUntil = 0
if not State._autoCarryFromSteal then
State._autoCarryReturnMode = currentSpeedMode
end
State._autoCarryFromSteal = true
State._autoCarryGraceUntil = tick() + 0.75
local wasLagger = (State._autoCarryReturnMode == "Lagger" or State._autoCarryReturnMode == "Lagger Carry"
or currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry")
if wasLagger then
State.laggerEnabled = true
State.speedToggled = true
if toggleRefs.laggerMode then toggleRefs.laggerMode(true) end
if toggleRefs.carryMode then toggleRefs.carryMode(true) end
setSpeedMode("Lagger Carry")
else
setLaggerMode(false)
setCarrySpeedMode(true)
end
safeSaveConfig()
end
local function disableAutoCarrySpeed()
if not State._autoCarryFromSteal and not State._waitingForCarryPickup then return end
local wasAutoApplied = State._autoCarryFromSteal == true
local returnMode = State._autoCarryReturnMode
State._autoCarryFromSteal = false
State._waitingForCarryPickup = false
State._autoCarryGraceUntil = 0
State._carryPickupWatchUntil = 0
State._autoCarryReturnMode = nil
if not wasAutoApplied then
return
end
if returnMode == "Lagger" or returnMode == "Lagger Carry" then
State.laggerEnabled = true
State.speedToggled = false
if toggleRefs.laggerMode then toggleRefs.laggerMode(true) end
if toggleRefs.carryMode then toggleRefs.carryMode(false) end
setSpeedMode("Lagger")
elseif returnMode == "Carry" then
State.laggerEnabled = false
State.speedToggled = true
if toggleRefs.laggerMode then toggleRefs.laggerMode(false) end
if toggleRefs.carryMode then toggleRefs.carryMode(true) end
setSpeedMode("Carry")
else
setLaggerMode(false)
setCarrySpeedMode(false)
end
safeSaveConfig()
end
local function startAutoCarryPickupWatch(seconds)
if autoCarrySpeedEnabled ~= true then return end
State._waitingForCarryPickup = true
State._carryPickupWatchUntil = tick() + (seconds or 1.25)
end
local _stealAttrWasActive = false
RunService.RenderStepped:Connect(function()
if autoCarrySpeedEnabled ~= true then
disableAutoCarrySpeed()
return
end
local char = LP.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local root = char and char:FindFirstChild("HumanoidRootPart")
if not char or not hum or not root then
disableAutoCarrySpeed()
_stealAttrWasActive = false
return
end
local st = hum:GetState()
local gotHit = st == Enum.HumanoidStateType.Physics
or st == Enum.HumanoidStateType.Ragdoll
or st == Enum.HumanoidStateType.FallingDown
local stealingAttr = LP:GetAttribute("Stealing") == true
local carryingBrainrot = isCarryingBrainrot(char)
if stealingAttr and not _stealAttrWasActive then
_stealAttrWasActive = true
enableCarrySpeedForSteal()
elseif not stealingAttr then
_stealAttrWasActive = false
end
if State._waitingForCarryPickup then
if gotHit or tick() > (State._carryPickupWatchUntil or 0) then
State._waitingForCarryPickup = false
State._carryPickupWatchUntil = 0
elseif carryingBrainrot then
enableCarrySpeedForSteal()
end
end
if carryingBrainrot and not State._autoCarryFromSteal then
enableCarrySpeedForSteal()
end
if State._autoCarryFromSteal then
local graceDone = tick() > (State._autoCarryGraceUntil or 0)
if gotHit or (graceDone and not carryingBrainrot and not stealingAttr) then
disableAutoCarrySpeed()
end
end
end)
_G.AutoCarrySpeed = {
IsCarryingBrainrot = isCarryingBrainrot,
Enable = enableCarrySpeedForSteal,
Disable = disableAutoCarrySpeed,
WatchPickup = startAutoCarryPickupWatch,
}
_G.DiceAutoPathState = _G.DiceAutoPathState or {leftConn=nil,rightConn=nil,leftPhase=1,rightPhase=1}
_G.DiceAutoPathPoints = _G.DiceAutoPathPoints or {
L1=Vector3.new(-476.48,-6.28,92.73), L2=Vector3.new(-483.12,-4.95,94.80), LFace=Vector3.new(-482.25,-4.96,92.09),
R1=Vector3.new(-476.16,-6.52,25.62), R2=Vector3.new(-483.06,-5.03,25.48), RFace=Vector3.new(-482.06,-6.93,35.47),
}
function _G.DiceAutoPathSpeed()
if currentSpeedMode == "Lagger" or currentSpeedMode == "Lagger Carry" then
return LAGGER_SPEED
end
return NS
end
function _G.DiceStopAutoLeft()
local S=_G.DiceAutoPathState
if S.leftConn then S.leftConn:Disconnect(); S.leftConn=nil end
S.leftPhase=1
local char=LP.Character
local hum=char and char:FindFirstChildOfClass("Humanoid")
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if hum then hum:Move(Vector3.zero,false) end
if hrp then hrp.AssemblyLinearVelocity=Vector3.new(0,hrp.AssemblyLinearVelocity.Y,0) end
end
function _G.DiceStopAutoRight()
local S=_G.DiceAutoPathState
if S.rightConn then S.rightConn:Disconnect(); S.rightConn=nil end
S.rightPhase=1
local char=LP.Character
local hum=char and char:FindFirstChildOfClass("Humanoid")
local hrp=char and char:FindFirstChild("HumanoidRootPart")
if hum then hum:Move(Vector3.zero,false) end
if hrp then hrp.AssemblyLinearVelocity=Vector3.new(0,hrp.AssemblyLinearVelocity.Y,0) end
end
function _G.DiceSetAutoLeft(on, skipSave)
if on and _G.DiceSafeModeTryStart and not _G.DiceSafeModeTryStart() then
autoLeftEnabled = false
if _G.DiceSetAutoLeftVisual then _G.DiceSetAutoLeftVisual(false) end
if not skipSave then saveDiceConfig() end
return false
end
autoLeftEnabled = on and true or false
if _G.DiceSetAutoLeftVisual then _G.DiceSetAutoLeftVisual(autoLeftEnabled) end
if autoLeftEnabled then
autoRightEnabled=false
if _G.DiceSetAutoRightVisual then _G.DiceSetAutoRightVisual(false) end
if _G.DiceStopAutoRight then _G.DiceStopAutoRight() end
if _G.DiceStartAutoLeft then _G.DiceStartAutoLeft() end
else
if _G.DiceStopAutoLeft then _G.DiceStopAutoLeft() end
end
if not skipSave then saveDiceConfig() end
end
function _G.DiceSetAutoRight(on, skipSave)
if on and _G.DiceSafeModeTryStart and not _G.DiceSafeModeTryStart() then
autoRightEnabled = false
if _G.DiceSetAutoRightVisual then _G.DiceSetAutoRightVisual(false) end
if not skipSave then saveDiceConfig() end
return false
end
autoRightEnabled = on and true or false
if _G.DiceSetAutoRightVisual then _G.DiceSetAutoRightVisual(autoRightEnabled) end
if autoRightEnabled then
autoLeftEnabled=false
if _G.DiceSetAutoLeftVisual then _G.DiceSetAutoLeftVisual(false) end
if _G.DiceStopAutoLeft then _G.DiceStopAutoLeft() end
if _G.DiceStartAutoRight then _G.DiceStartAutoRight() end
else
if _G.DiceStopAutoRight then _G.DiceStopAutoRight() end
end
if not skipSave then saveDiceConfig() end
end
function _G.DiceStartAutoLeft()
local S=_G.DiceAutoPathState
if S.leftConn then S.leftConn:Disconnect() end
S.leftPhase=1
S.leftConn=RunService.Heartbeat:Connect(function()
if not autoLeftEnabled then return end
local char=LP.Character; if not char then return end
local hrp=char:FindFirstChild("HumanoidRootPart")
local hum=char:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then return end
local st=hum:GetState()
if hum.PlatformStand or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then hum:Move(Vector3.zero,false); return end
local P=_G.DiceAutoPathPoints
local spd=_G.DiceAutoPathSpeed()
if S.leftPhase==1 then
local tgt=Vector3.new(P.L1.X,hrp.Position.Y,P.L1.Z)
if (tgt-hrp.Position).Magnitude<1 then
S.leftPhase=2
local d=P.L2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
return
end
local d=P.L1-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
elseif S.leftPhase==2 then
local tgt=Vector3.new(P.L2.X,hrp.Position.Y,P.L2.Z)
if (tgt-hrp.Position).Magnitude<1 then
hum:Move(Vector3.zero,false)
hrp.AssemblyLinearVelocity=Vector3.zero
autoLeftEnabled=false
if S.leftConn then S.leftConn:Disconnect(); S.leftConn=nil end
S.leftPhase=1
if _G.DiceSetAutoLeftVisual then _G.DiceSetAutoLeftVisual(false) end
if P.LFace and (P.LFace-hrp.Position).Magnitude>0.01 then
hrp.CFrame=CFrame.new(hrp.Position,Vector3.new(P.LFace.X,hrp.Position.Y,P.LFace.Z))
end
saveDiceConfig()
return
end
local d=P.L2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
end
end)
end
function _G.DiceStartAutoRight()
local S=_G.DiceAutoPathState
if S.rightConn then S.rightConn:Disconnect() end
S.rightPhase=1
S.rightConn=RunService.Heartbeat:Connect(function()
if not autoRightEnabled then return end
local char=LP.Character; if not char then return end
local hrp=char:FindFirstChild("HumanoidRootPart")
local hum=char:FindFirstChildOfClass("Humanoid")
if not hrp or not hum then return end
local st=hum:GetState()
if hum.PlatformStand or st==Enum.HumanoidStateType.Physics or st==Enum.HumanoidStateType.Ragdoll or st==Enum.HumanoidStateType.FallingDown then hum:Move(Vector3.zero,false); return end
local P=_G.DiceAutoPathPoints
local spd=_G.DiceAutoPathSpeed()
if S.rightPhase==1 then
local tgt=Vector3.new(P.R1.X,hrp.Position.Y,P.R1.Z)
if (tgt-hrp.Position).Magnitude<1 then
S.rightPhase=2
local d=P.R2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
return
end
local d=P.R1-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
elseif S.rightPhase==2 then
local tgt=Vector3.new(P.R2.X,hrp.Position.Y,P.R2.Z)
if (tgt-hrp.Position).Magnitude<1 then
hum:Move(Vector3.zero,false)
hrp.AssemblyLinearVelocity=Vector3.zero
autoRightEnabled=false
if S.rightConn then S.rightConn:Disconnect(); S.rightConn=nil end
S.rightPhase=1
if _G.DiceSetAutoRightVisual then _G.DiceSetAutoRightVisual(false) end
if P.RFace and (P.RFace-hrp.Position).Magnitude>0.01 then
hrp.CFrame=CFrame.new(hrp.Position,Vector3.new(P.RFace.X,hrp.Position.Y,P.RFace.Z))
end
saveDiceConfig()
return
end
local d=P.R2-hrp.Position
local mv=Vector3.new(d.X,0,d.Z).Unit
hum:Move(mv,false)
hrp.AssemblyLinearVelocity=Vector3.new(mv.X*spd,hrp.AssemblyLinearVelocity.Y,mv.Z*spd)
end
end)
end
LP.CharacterAdded:Connect(function()
task.wait(0.5)
if autoLeftEnabled and _G.DiceStartAutoLeft then _G.DiceStartAutoLeft() end
if autoRightEnabled and _G.DiceStartAutoRight then _G.DiceStartAutoRight() end
end)
local overheadGui = nil
local overheadSpeedLabel = nil
local function setupOverheadInfo(char)
if overheadGui then
pcall(function() overheadGui:Destroy() end)
overheadGui = nil
overheadSpeedLabel = nil
end
if not char then return end
local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
if not head then return end
overheadGui = Instance.new("BillboardGui")
overheadGui.Name = "DiceDuelsOverheadInfo"
overheadGui.Size = UDim2.new(0, 250, 0, 88)
overheadGui.StudsOffset = Vector3.new(0, 1.75, 0)
overheadGui.AlwaysOnTop = true
overheadGui.LightInfluence = 0
overheadGui.Parent = head
ragdollCountdownLabel = Instance.new("TextLabel")
ragdollCountdownLabel.Name = "RagdollCountdown"
ragdollCountdownLabel.Size = UDim2.new(1, 0, 0, 26)
ragdollCountdownLabel.Position = UDim2.new(0, 0, 0, 0)
ragdollCountdownLabel.BackgroundTransparency = 1
ragdollCountdownLabel.Text = ""
ragdollCountdownLabel.Visible = false
ragdollCountdownLabel.TextColor3 = Color3.fromRGB(240, 240, 244)
ragdollCountdownLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
ragdollCountdownLabel.TextStrokeTransparency = 0
ragdollCountdownLabel.Font = Enum.Font.GothamBlack
ragdollCountdownLabel.TextSize = 22
ragdollCountdownLabel.TextXAlignment = Enum.TextXAlignment.Center
ragdollCountdownLabel.ZIndex = 10
ragdollCountdownLabel.Parent = overheadGui
-- Speed on top, discord under it, both heavy white on a thick black
-- outline so they hold up against whatever is behind the character.
overheadSpeedLabel = Instance.new("TextLabel")
overheadSpeedLabel.Name = "Speed"
overheadSpeedLabel.Size = UDim2.new(1, 0, 0, 32)
overheadSpeedLabel.Position = UDim2.new(0, 0, 0, 24)
overheadSpeedLabel.BackgroundTransparency = 1
overheadSpeedLabel.Text = "Speed: 0 | Normal"
overheadSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
overheadSpeedLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
overheadSpeedLabel.TextStrokeTransparency = 0
overheadSpeedLabel.Font = Enum.Font.GothamBlack
overheadSpeedLabel.TextSize = 26
overheadSpeedLabel.TextXAlignment = Enum.TextXAlignment.Center
overheadSpeedLabel.ZIndex = 10
overheadSpeedLabel.Parent = overheadGui
do
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(0, 0, 0)
outline.Thickness = 2.5
outline.Transparency = 0
outline.Parent = overheadSpeedLabel
end
local discordLbl = Instance.new("TextLabel")
discordLbl.Name = "Discord"
discordLbl.Size = UDim2.new(1, 0, 0, 28)
discordLbl.Position = UDim2.new(0, 0, 0, 56)
discordLbl.BackgroundTransparency = 1
discordLbl.Text = "discord.gg/qgwhrFZXd"
discordLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
discordLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
-- Lighter than the speed line above it: the handle is there to be read,
-- not to compete with the number.
discordLbl.TextStrokeTransparency = 0.35
discordLbl.Font = Enum.Font.GothamBold
discordLbl.TextSize = 19
discordLbl.TextXAlignment = Enum.TextXAlignment.Center
discordLbl.ZIndex = 10
discordLbl.Parent = overheadGui
end
local ragdollCountdownConn = nil
local ragdollCountdownCharConn = nil
local ragdollCountdownEndTime = 0
local RAGDOLL_COUNTDOWN_SECONDS = 2.6
function stopRagdollCountdown()
if ragdollCountdownConn then ragdollCountdownConn:Disconnect(); ragdollCountdownConn = nil end
if ragdollCountdownCharConn then ragdollCountdownCharConn:Disconnect(); ragdollCountdownCharConn = nil end
if ragdollCountdownLabel then
ragdollCountdownLabel.Visible = false
ragdollCountdownLabel.Text = ""
end
end
function hookRagdollCountdown(char)
stopRagdollCountdown()
if not ragdollCountdownEnabled then return end
char = char or LP.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 4)
if not hum then return end
local function beginCountdown()
ragdollCountdownEndTime = tick() + RAGDOLL_COUNTDOWN_SECONDS
if ragdollCountdownLabel then
ragdollCountdownLabel.Visible = true
end
end
local function isRagdollStateForCountdown()
local st = hum:GetState()
return hum.PlatformStand
or st == Enum.HumanoidStateType.Physics
or st == Enum.HumanoidStateType.Ragdoll
or st == Enum.HumanoidStateType.FallingDown
end
ragdollCountdownCharConn = hum.StateChanged:Connect(function(_, newState)
if newState == Enum.HumanoidStateType.Physics
or newState == Enum.HumanoidStateType.Ragdoll
or newState == Enum.HumanoidStateType.FallingDown then
beginCountdown()
end
end)
ragdollCountdownConn = RunService.RenderStepped:Connect(function()
if not ragdollCountdownEnabled then stopRagdollCountdown(); return end
if not ragdollCountdownLabel or not ragdollCountdownLabel.Parent then return end
if isRagdollStateForCountdown() and ragdollCountdownEndTime < tick() then
beginCountdown()
end
local left = math.max(0, ragdollCountdownEndTime - tick())
if left > 0 then
ragdollCountdownLabel.Visible = true
ragdollCountdownLabel.Text = string.format("RAGDOLL %.1f", left)
if left <= 1 then
ragdollCountdownLabel.TextColor3 = Color3.fromRGB(150, 150, 156)
else
ragdollCountdownLabel.TextColor3 = Color3.fromRGB(240, 240, 244)
end
else
ragdollCountdownLabel.Visible = false
ragdollCountdownLabel.Text = ""
end
end)
end
if LP.Character then
task.spawn(function()
setupOverheadInfo(LP.Character)
end)
end
LP.CharacterAdded:Connect(function(char)
task.wait(0.5)
setupOverheadInfo(char)
if ragdollCountdownEnabled then hookRagdollCountdown(char) end
end)
RunService.RenderStepped:Connect(function()
local char = LP.Character
if not char then return end
local hum = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hum or not hrp then return end
local state = hum:GetState()
if hum.PlatformStand
or state == Enum.HumanoidStateType.Physics
or state == Enum.HumanoidStateType.Ragdoll
or state == Enum.HumanoidStateType.FallingDown then
lastMoveDir = Vector3.new(0, 0, 0)
-- Ragdolled: hand the humanoid back rather than holding it off default
-- while the game has control.
DiceReleaseWalkSpeed(hum)
return
end
if not autoLeftEnabled and not autoRightEnabled then
local md = hum.MoveDirection
local spd = getCurrentSpeedValue()
local dir = Vector3.new(0, 0, 0)
if md.Magnitude > 0 then
lastMoveDir = md
dir = md
elseif antiRagdollEnabled and lastMoveDir.Magnitude > 0 then
-- MoveDirection drops to zero the instant a ragdoll starts, so with
-- anti ragdoll on we keep driving the last heading while the key is
-- still down instead of stalling mid-stride.
local anyHeld = false
for key in pairs(MOVE_KEYS) do
if UserInputService:IsKeyDown(key) then anyHeld = true break end
end
if anyHeld then dir = lastMoveDir end
end
if dir.Magnitude > 0 then
DiceApplyMoveSpeed(hrp, hum, dir, spd)
else
DiceReleaseWalkSpeed(hum)
end
else
-- Auto path drives the character itself.
DiceReleaseWalkSpeed(hum)
end
if overheadSpeedLabel then
local v = hrp.AssemblyLinearVelocity or hrp.Velocity
local speedMag = Vector3.new(v.X, 0, v.Z).Magnitude
local rounded = math.floor(speedMag * 10 + 0.5) / 10
local shown
if math.abs(rounded - math.floor(rounded)) < 0.05 then
shown = string.format("%d", math.floor(rounded + 0.5))
else
shown = string.format("%.1f", rounded)
end
overheadSpeedLabel.Text = string.format("Speed: %s | %s", shown, tostring(currentSpeedMode or "Normal"))
end
end)
-- Monochrome dice table: near-black panels, white pips, white accent.
-- There is no hue anywhere in the palette on purpose — the accent is
-- plain white and does the work a colour would normally do.
local COLORS = {
bg = Color3.fromRGB(8, 8, 9),
row = Color3.fromRGB(19, 19, 21),
row2 = Color3.fromRGB(26, 26, 29),
stroke = Color3.fromRGB(78, 78, 84),
strokeSoft = Color3.fromRGB(52, 52, 57),
white = Color3.fromRGB(244, 244, 247),
textDim = Color3.fromRGB(150, 150, 156),
toggleBg = Color3.fromRGB(28, 28, 32),
knob = Color3.fromRGB(244, 244, 248),
accent = Color3.fromRGB(240, 240, 244),
accentDim = Color3.fromRGB(122, 122, 128),
accentSoft = Color3.fromRGB(38, 38, 42),
}
function corner(parent, radius)
local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, radius or 8)
c.Parent = parent
return c
end
function stroke(parent, color, thickness, transparency)
local s = Instance.new("UIStroke")
s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
s.Color = color or COLORS.stroke
s.Thickness = thickness or 1
s.Transparency = transparency or 0.35
s.Parent = parent
-- Flat border. The shimmering gradient that used to live here fought
-- with the dice motif and made every edge look the same shade of busy.
return s
end
function tween(obj, props, time)
TweenService:Create(obj, TweenInfo.new(time or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
-- ═══════════════════════════════════════════════════════════════
-- DICE
-- Drawn from frames, so there is no image asset to load and the faces
-- can be repainted at will. Each die is a stack — contact shadow, the
-- block's extruded edge, a lit face under a bevelled rim, and pips
-- drilled into the surface — lit consistently from the top left.
-- Returns the die and a face setter.
-- ═══════════════════════════════════════════════════════════════
local DIE_PIPS = {
[1] = {{0.5, 0.5}},
[2] = {{0.28, 0.28}, {0.72, 0.72}},
[3] = {{0.26, 0.26}, {0.5, 0.5}, {0.74, 0.74}},
[4] = {{0.28, 0.28}, {0.72, 0.28}, {0.28, 0.72}, {0.72, 0.72}},
[5] = {{0.27, 0.27}, {0.73, 0.27}, {0.5, 0.5}, {0.27, 0.73}, {0.73, 0.73}},
[6] = {{0.28, 0.23}, {0.72, 0.23}, {0.28, 0.5}, {0.72, 0.5}, {0.28, 0.77}, {0.72, 0.77}},
}
function makeDie(parent, sizePx, value, dark, fade)
fade = tonumber(fade) or 0
-- Every layer dims together, so transparencies are quoted at full
-- strength and pushed through this.
local function dim(t) return t + (1 - t) * fade end
-- Below ~20px the sheen and the drilled pip rims land on half a pixel
-- and just muddy the face; past half transparency nobody can see them
-- either. Either way they are instances the backdrop need not pay for.
local detailed = sizePx >= 20 and fade < 0.5
local radius = math.max(3, math.floor(sizePx * 0.2))
local depth = math.max(1, math.floor(sizePx * 0.085))
local die = Instance.new("Frame")
die.Name = "Die"
die.Size = UDim2.new(0, sizePx, 0, sizePx)
die.BackgroundTransparency = 1
die.BorderSizePixel = 0
die.ZIndex = (parent.ZIndex or 1) + 1
die.Parent = parent
local z = die.ZIndex
-- Contact shadow, softened by stacking two offset layers.
for i = 1, (detailed and 2 or 1) do
local shade = Instance.new("Frame")
shade.Name = "Shadow" .. i
shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shade.BackgroundTransparency = dim(0.42 + (i - 1) * 0.26)
shade.BorderSizePixel = 0
shade.Position = UDim2.new(0, depth + i, 0, depth + i + 1)
shade.Size = UDim2.new(1, i, 1, i)
shade.ZIndex = z
shade.Parent = die
corner(shade, radius + i)
end
-- The extruded edge of the block, offset down-right and turned away
-- from the light, so the face reads as the top of a cube.
local block = Instance.new("Frame")
block.Name = "Block"
block.BackgroundColor3 = dark and Color3.fromRGB(8, 8, 10) or Color3.fromRGB(126, 126, 132)
block.BackgroundTransparency = dim(0)
block.BorderSizePixel = 0
block.Position = UDim2.new(0, depth, 0, depth)
block.Size = UDim2.new(1, 0, 1, 0)
block.ZIndex = z + 1
block.Parent = die
corner(block, radius)
do
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new(
dark and Color3.fromRGB(32, 32, 36) or Color3.fromRGB(170, 170, 176),
dark and Color3.fromRGB(3, 3, 4) or Color3.fromRGB(88, 88, 94))
g.Rotation = 90
g.Parent = block
end
-- The lit face.
local face = Instance.new("Frame")
face.Name = "Face"
face.BackgroundColor3 = dark and Color3.fromRGB(24, 24, 28) or Color3.fromRGB(248, 248, 251)
face.BackgroundTransparency = dim(0)
face.BorderSizePixel = 0
face.Size = UDim2.new(1, 0, 1, 0)
face.ZIndex = z + 2
face.Parent = die
corner(face, radius)
do
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, dark and Color3.fromRGB(58, 58, 64) or Color3.fromRGB(255, 255, 255)),
ColorSequenceKeypoint.new(0.5, dark and Color3.fromRGB(26, 26, 30) or Color3.fromRGB(237, 237, 242)),
ColorSequenceKeypoint.new(1, dark and Color3.fromRGB(9, 9, 11) or Color3.fromRGB(196, 196, 204)),
})
g.Rotation = 118
g.Parent = face
end
-- Bevelled rim: bright along the lit edge, dark where it turns away.
local rim = Instance.new("UIStroke")
rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rim.Thickness = math.max(1, sizePx * 0.05)
rim.Transparency = dim(0.12)
rim.Color = Color3.fromRGB(255, 255, 255)
rim.Parent = face
do
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new(
dark and Color3.fromRGB(104, 104, 112) or Color3.fromRGB(255, 255, 255),
dark and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(112, 112, 120))
g.Rotation = 118
g.Parent = rim
end
if detailed then
local sheen = Instance.new("Frame")
sheen.Name = "Sheen"
sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sheen.BackgroundTransparency = dim(dark and 0.8 or 0.55)
sheen.BorderSizePixel = 0
sheen.Position = UDim2.new(0, math.floor(sizePx * 0.1), 0, math.floor(sizePx * 0.08))
sheen.Size = UDim2.new(1, -math.floor(sizePx * 0.2), 0, math.max(2, math.floor(sizePx * 0.34)))
sheen.ZIndex = z + 3
sheen.Parent = face
corner(sheen, math.max(2, math.floor(radius * 0.8)))
local g = Instance.new("UIGradient")
g.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0),
NumberSequenceKeypoint.new(1, 1),
})
g.Rotation = 90
g.Parent = sheen
end
local pipSize = math.max(2, math.floor(sizePx * 0.19))
-- Six pips is the most any face needs; the rest are hidden per value.
local pips = {}
for i = 1, 6 do
local pip = Instance.new("Frame")
pip.Name = "Pip" .. i
pip.AnchorPoint = Vector2.new(0.5, 0.5)
pip.Size = UDim2.new(0, pipSize, 0, pipSize)
pip.BackgroundColor3 = dark and Color3.fromRGB(238, 238, 244) or Color3.fromRGB(20, 20, 23)
pip.BackgroundTransparency = dim(0)
pip.BorderSizePixel = 0
pip.Visible = false
pip.ZIndex = z + 4
pip.Parent = face
corner(pip, 999)
-- Drilled, not painted. With the key light up at the top left, the
-- near wall of the hole shades itself and the far wall catches the
-- bounce, so the gradient runs along the same axis as the face.
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new(
dark and Color3.fromRGB(252, 252, 255) or Color3.fromRGB(4, 4, 6),
dark and Color3.fromRGB(172, 172, 180) or Color3.fromRGB(84, 84, 92))
g.Rotation = 118
g.Parent = pip
if detailed then
local lip = Instance.new("UIStroke")
lip.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
lip.Thickness = math.max(0.5, sizePx * 0.018)
lip.Transparency = dim(0.45)
lip.Color = dark and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
lip.Parent = pip
-- The polished edge of the bore only catches light on the far side.
local lg = Instance.new("UIGradient")
lg.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 1),
NumberSequenceKeypoint.new(1, 0),
})
lg.Rotation = 118
lg.Parent = lip
end
pips[i] = pip
end
local function setFace(v)
v = math.clamp(math.floor(tonumber(v) or 1), 1, 6)
local layout = DIE_PIPS[v]
for i = 1, 6 do
local spot = layout[i]
pips[i].Visible = spot ~= nil
if spot then
pips[i].Position = UDim2.new(spot[1], 0, spot[2], 0)
end
end
end
setFace(value or 1)
return die, setFace
end
function makeDraggable(frame, handle)
handle = handle or frame
local dragging = false
local dragStart
local startPos
local dragInput
handle.InputBegan:Connect(function(input)
if _G.DiceGuiLocked == true then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
dragStart = input.Position
startPos = frame.Position
input.Changed:Connect(function()
if input.UserInputState == Enum.UserInputState.End then
dragging = false
end
end)
end
end)
handle.InputChanged:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
dragInput = input
end
end)
UserInputService.InputChanged:Connect(function(input)
if _G.DiceGuiLocked == true then return end
if input == dragInput and dragging then
local delta = input.Position - dragStart
frame.Position = UDim2.new(
startPos.X.Scale,
startPos.X.Offset + delta.X,
startPos.Y.Scale,
startPos.Y.Offset + delta.Y
)
end
end)
end
local Gui = Instance.new("ScreenGui")
Gui.Name = "DiceDuelsAdaptReconstruct"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui
local FULL_MAIN_SIZE = UDim2.new(0, 440, 0, 580)
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0, 0.5)
Main.Size = FULL_MAIN_SIZE
Main.Position = tableToUDim2(savedMainPositionTable, UDim2.new(0, 20, 0.5, 0))
savedMainPositionTable = udim2ToTable(Main.Position)
Main.BackgroundColor3 = COLORS.bg
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = false
Main.Parent = Gui
corner(Main, 14)
stroke(Main, COLORS.stroke, 1.1, 0.35)
makeDraggable(Main)
Main:GetPropertyChangedSignal("Position"):Connect(function()
savedMainPositionTable = udim2ToTable(Main.Position)
end)
local MiniFrame = Instance.new("Frame")
MiniFrame.Name = "MiniFrame"
MiniFrame.AnchorPoint = Vector2.new(0, 0)
MiniFrame.Size = UDim2.new(0, 46, 0, 46)
local MINI_DEFAULT_POSITION = UDim2.new(0, 132, 0, 112)
MiniFrame.Position = MINI_DEFAULT_POSITION
savedMiniPositionTable = nil
MiniFrame.BackgroundTransparency = 1
MiniFrame.BorderSizePixel = 0
MiniFrame.Visible = false
MiniFrame.Active = true
MiniFrame.ZIndex = 20
MiniFrame.Parent = Gui
-- The collapsed handle is a die rather than a labelled tab.
local MiniDie, setMiniDieFace = makeDie(MiniFrame, 46, 6, false)
MiniDie.Name = "MiniDie"
MiniDie.Position = UDim2.new(0, 0, 0, 0)
local MiniButton = Instance.new("TextButton")
MiniButton.Name = "MiniButton"
MiniButton.Size = UDim2.new(1, 0, 1, 0)
MiniButton.BackgroundTransparency = 1
MiniButton.Text = ""
MiniButton.AutoButtonColor = false
MiniButton.ZIndex = 25
MiniButton.Parent = MiniFrame
-- Fresh roll every time it appears.
MiniFrame:GetPropertyChangedSignal("Visible"):Connect(function()
if MiniFrame.Visible then setMiniDieFace(math.random(1, 6)) end
end)
do
local miniDragging = false
local miniDragStart = nil
local miniStartPos = nil
local miniMoved = false
local miniHeldInput = nil
local DRAG_DEADZONE = 6
MiniButton.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
miniDragging = true
miniMoved = false
miniHeldInput = input
miniDragStart = input.Position
miniStartPos = MiniFrame.Position
end
end)
UserInputService.InputChanged:Connect(function(input)
if not miniDragging then return end
if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
if not miniDragStart or not miniStartPos then return end
local delta = input.Position - miniDragStart
if math.abs(delta.X) > DRAG_DEADZONE or math.abs(delta.Y) > DRAG_DEADZONE then
miniMoved = true
end
MiniFrame.Position = UDim2.new(
miniStartPos.X.Scale,
miniStartPos.X.Offset + delta.X,
miniStartPos.Y.Scale,
miniStartPos.Y.Offset + delta.Y
)
end)
UserInputService.InputEnded:Connect(function(input)
if input ~= miniHeldInput then return end
local wasDrag = miniMoved
miniDragging = false
miniHeldInput = nil
miniDragStart = nil
miniStartPos = nil
if wasDrag then
return
end
Main.Visible = true
MiniFrame.Visible = false
Main.Size = FULL_MAIN_SIZE
savedMainPositionTable = udim2ToTable(Main.Position)
end)
end

-- ═══════════════════════════════════════════════════════════════
-- BACKDROP — faded dice scattered behind the panels. Sits low in the
-- stack so the translucent sidebar and content pane read over the top.
-- ═══════════════════════════════════════════════════════════════
-- Scoped so the panel's furniture does not eat main-chunk local
-- slots; Luau caps a function at 200 of them and this file is close.
do
local DiceBackdrop = Instance.new("Frame")
DiceBackdrop.Name = "DiceBackdrop"
DiceBackdrop.BackgroundTransparency = 1
DiceBackdrop.Size = UDim2.new(1, 0, 1, 0)
DiceBackdrop.Position = UDim2.new(0, 0, 0, 0)
DiceBackdrop.ClipsDescendants = true
DiceBackdrop.ZIndex = 2
DiceBackdrop.Parent = Main
corner(DiceBackdrop, 14)
local backdropDieSetters = {}
do
-- All light faced: a dark die on a near-black panel reads as nothing.
local layout = {
{x = 0.09, y = 0.16, size = 62, rot = -14, face = 5},
{x = 0.29, y = 0.62, size = 46, rot = 12, face = 3},
{x = 0.54, y = 0.13, size = 72, rot = -7, face = 6},
{x = 0.80, y = 0.42, size = 52, rot = 18, face = 2},
{x = 0.93, y = 0.78, size = 64, rot = -12, face = 4},
{x = 0.16, y = 0.89, size = 40, rot = 23, face = 1},
{x = 0.65, y = 0.87, size = 44, rot = -20, face = 5},
{x = 0.42, y = 0.34, size = 36, rot = 7, face = 2},
{x = 0.71, y = 0.63, size = 34, rot = -25, face = 3},
{x = 0.35, y = 0.10, size = 30, rot = 15, face = 4},
}
for _, spec in ipairs(layout) do
local die, setFace = makeDie(DiceBackdrop, spec.size, spec.face, false, 0.85)
die.AnchorPoint = Vector2.new(0.5, 0.5)
die.Position = UDim2.new(spec.x, 0, spec.y, 0)
die.Rotation = spec.rot
table.insert(backdropDieSetters, setFace)
end
end
-- Re-rolled alongside the title pair whenever you change tab.
function rollBackdropDice()
for _, setFace in ipairs(backdropDieSetters) do
setFace(math.random(1, 6))
end
end
end


-- ═══════════════════════════════════════════════════════════════
-- LIGHTNING STRIKES SYSTEM — detailed procedural lightning bolts
-- ═══════════════════════════════════════════════════════════════
do
	local LIGHTNING_COLORS = {
		primary   = Color3.fromRGB(226, 226, 230),
		core      = Color3.fromRGB(255, 255, 255),
		glow      = Color3.fromRGB(150, 150, 156),
		branch    = Color3.fromRGB(190, 190, 196),
		spark     = Color3.fromRGB(238, 238, 242),
		flash     = Color3.fromRGB(205, 205, 210),
		ambient   = Color3.fromRGB(120, 120, 126),
	}

	local LightningContainer = Instance.new("Frame")
	LightningContainer.Name = "LightningFX"
	LightningContainer.BackgroundTransparency = 1
	LightningContainer.Size = UDim2.new(1, 0, 1, 0)
	LightningContainer.Position = UDim2.new(0, 0, 0, 0)
	LightningContainer.ClipsDescendants = true
	LightningContainer.ZIndex = 2
	LightningContainer.Parent = Main
	corner(LightningContainer, 14)

	local FlashOverlay = Instance.new("Frame")
	FlashOverlay.Name = "FlashOverlay"
	FlashOverlay.BackgroundColor3 = LIGHTNING_COLORS.flash
	FlashOverlay.BackgroundTransparency = 1
	FlashOverlay.Size = UDim2.new(1, 0, 1, 0)
	FlashOverlay.ZIndex = 2
	FlashOverlay.Parent = LightningContainer
	corner(FlashOverlay, 14)

	local AmbientGlow = Instance.new("Frame")
	AmbientGlow.Name = "AmbientGlow"
	AmbientGlow.BackgroundColor3 = LIGHTNING_COLORS.ambient
	AmbientGlow.BackgroundTransparency = 1
	AmbientGlow.Size = UDim2.new(1, 0, 1, 0)
	AmbientGlow.ZIndex = 2
	AmbientGlow.Parent = LightningContainer
	corner(AmbientGlow, 14)

	local GlowGradient = Instance.new("UIGradient")
	GlowGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 126)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(58, 58, 62)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 126)),
	})
	GlowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	GlowGradient.Parent = AmbientGlow

	local rng = Random.new(tick())

	local function createSegment(parent, x1, y1, x2, y2, thickness, color, transparency, zindex)
		local dx = x2 - x1
		local dy = y2 - y1
		local length = math.sqrt(dx * dx + dy * dy)
		local angle = math.atan2(dy, dx)

		local seg = Instance.new("Frame")
		seg.BackgroundColor3 = color or LIGHTNING_COLORS.primary
		seg.BackgroundTransparency = transparency or 0
		seg.BorderSizePixel = 0
		seg.Size = UDim2.new(0, math.max(length, 1), 0, thickness or 2)
		seg.Position = UDim2.new(0, x1, 0, y1)
		seg.AnchorPoint = Vector2.new(0, 0.5)
		seg.Rotation = math.deg(angle)
		seg.ZIndex = zindex or 3
		seg.Parent = parent

		local segGlow = Instance.new("Frame")
		segGlow.BackgroundColor3 = LIGHTNING_COLORS.glow
		segGlow.BackgroundTransparency = 0.5
		segGlow.BorderSizePixel = 0
		segGlow.Size = UDim2.new(1, 4, 0, (thickness or 2) + 4)
		segGlow.Position = UDim2.new(0, -2, 0.5, 0)
		segGlow.AnchorPoint = Vector2.new(0, 0.5)
		segGlow.ZIndex = (zindex or 3) - 1
		segGlow.Parent = seg

		return seg
	end

	local function generateBoltPath(startX, startY, endX, endY, segments, jitter)
		local points = {}
		segments = segments or 12
		jitter = jitter or 18
		for i = 0, segments do
			local t = i / segments
			local px = startX + (endX - startX) * t
			local py = startY + (endY - startY) * t
			if i > 0 and i < segments then
				px = px + rng:NextNumber(-jitter, jitter)
				py = py + rng:NextNumber(-jitter * 0.4, jitter * 0.4)
			end
			table.insert(points, {x = px, y = py})
		end
		return points
	end

	local function drawBolt(parent, points, thickness, color, transparency, zindex)
		local segments = {}
		for i = 1, #points - 1 do
			local p1 = points[i]
			local p2 = points[i + 1]
			local seg = createSegment(parent, p1.x, p1.y, p2.x, p2.y, thickness, color, transparency, zindex)
			table.insert(segments, seg)
		end
		return segments
	end

	local function drawBranch(parent, originX, originY, angle, length, depth, segments)
		if depth <= 0 or length < 6 then return {} end
		local endX = originX + math.cos(angle) * length
		local endY = originY + math.sin(angle) * length
		local branchSegs = math.max(3, math.floor(segments * 0.6))
		local pts = generateBoltPath(originX, originY, endX, endY, branchSegs, length * 0.18)
		local thickness = math.max(1, 3 - depth)
		local allSegs = drawBolt(parent, pts, thickness, LIGHTNING_COLORS.branch, 0.15 + depth * 0.12, 3)
		if depth > 0 and rng:NextNumber() > 0.4 then
			local branchPt = pts[math.floor(#pts * rng:NextNumber(0.3, 0.7))]
			if branchPt then
				local subAngle = angle + rng:NextNumber(-0.8, 0.8)
				local subLen = length * rng:NextNumber(0.35, 0.6)
				local subSegs = drawBranch(parent, branchPt.x, branchPt.y, subAngle, subLen, depth - 1, branchSegs)
				for _, s in ipairs(subSegs) do table.insert(allSegs, s) end
			end
		end
		return allSegs
	end

	local function createSpark(parent, x, y)
		local sparkSize = rng:NextInteger(2, 5)
		local spark = Instance.new("Frame")
		spark.BackgroundColor3 = LIGHTNING_COLORS.spark
		spark.BackgroundTransparency = 0
		spark.BorderSizePixel = 0
		spark.Size = UDim2.new(0, sparkSize, 0, sparkSize)
		spark.Position = UDim2.new(0, x - sparkSize / 2, 0, y - sparkSize / 2)
		spark.ZIndex = 4
		spark.Parent = parent
		corner(spark, sparkSize)

		local sparkGlow = Instance.new("Frame")
		sparkGlow.BackgroundColor3 = LIGHTNING_COLORS.glow
		sparkGlow.BackgroundTransparency = 0.3
		sparkGlow.BorderSizePixel = 0
		sparkGlow.Size = UDim2.new(0, sparkSize + 6, 0, sparkSize + 6)
		sparkGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
		sparkGlow.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkGlow.ZIndex = 3
		sparkGlow.Parent = spark
		corner(sparkGlow, sparkSize + 6)

		return spark
	end

	local function clearLightningChildren(container)
		for _, child in ipairs(container:GetChildren()) do
			if child.Name ~= "FlashOverlay" and child.Name ~= "AmbientGlow"
			   and not child:IsA("UICorner") and not child:IsA("UIGradient") then
				child:Destroy()
			end
		end
	end

	local function fireStrike()
		clearLightningChildren(LightningContainer)

		local mainW = Main.AbsoluteSize.X
		local mainH = Main.AbsoluteSize.Y
		if mainW < 10 or mainH < 10 then return end

		local strikeType = rng:NextInteger(1, 4)
		local allSegments = {}
		local allSparks = {}

		if strikeType == 1 then
			local startX = rng:NextNumber(mainW * 0.15, mainW * 0.85)
			local pts = generateBoltPath(startX, -4, startX + rng:NextNumber(-40, 40), mainH + 4, 16, 22)
			local segs = drawBolt(LightningContainer, pts, 2.5, LIGHTNING_COLORS.core, 0, 4)
			for _, s in ipairs(segs) do table.insert(allSegments, s) end
			local coreSegs = drawBolt(LightningContainer, pts, 1, LIGHTNING_COLORS.core, 0, 5)
			for _, s in ipairs(coreSegs) do table.insert(allSegments, s) end
			for i = 1, rng:NextInteger(2, 4) do
				local branchIdx = math.floor(#pts * rng:NextNumber(0.15, 0.75))
				local branchPt = pts[branchIdx] or pts[math.floor(#pts / 2)]
				local angle = rng:NextNumber(-1.2, 1.2) + (math.pi / 2)
				local branchLen = rng:NextNumber(30, 70)
				local brSegs = drawBranch(LightningContainer, branchPt.x, branchPt.y, angle, branchLen, 2, 8)
				for _, s in ipairs(brSegs) do table.insert(allSegments, s) end
			end
			for _, pt in ipairs(pts) do
				if rng:NextNumber() > 0.7 then
					local sp = createSpark(LightningContainer, pt.x + rng:NextNumber(-6, 6), pt.y + rng:NextNumber(-6, 6))
					table.insert(allSparks, sp)
				end
			end

		elseif strikeType == 2 then
			local startY = rng:NextNumber(mainH * 0.1, mainH * 0.5)
			local pts = generateBoltPath(-4, startY, mainW + 4, startY + rng:NextNumber(-30, 30), 14, 18)
			local segs = drawBolt(LightningContainer, pts, 2, LIGHTNING_COLORS.primary, 0, 4)
			for _, s in ipairs(segs) do table.insert(allSegments, s) end
			local coreSegs = drawBolt(LightningContainer, pts, 1, LIGHTNING_COLORS.core, 0, 5)
			for _, s in ipairs(coreSegs) do table.insert(allSegments, s) end
			for i = 1, rng:NextInteger(1, 3) do
				local branchIdx = math.floor(#pts * rng:NextNumber(0.2, 0.8))
				local branchPt = pts[branchIdx] or pts[math.floor(#pts / 2)]
				local angle = rng:NextNumber(-1.0, 1.0)
				local branchLen = rng:NextNumber(25, 55)
				local brSegs = drawBranch(LightningContainer, branchPt.x, branchPt.y, angle, branchLen, 2, 6)
				for _, s in ipairs(brSegs) do table.insert(allSegments, s) end
			end
			for _, pt in ipairs(pts) do
				if rng:NextNumber() > 0.75 then
					local sp = createSpark(LightningContainer, pt.x + rng:NextNumber(-5, 5), pt.y + rng:NextNumber(-5, 5))
					table.insert(allSparks, sp)
				end
			end

		elseif strikeType == 3 then
			local cx = mainW / 2
			local cy = mainH * rng:NextNumber(0.25, 0.55)
			local numArms = rng:NextInteger(3, 6)
			for arm = 1, numArms do
				local angle = (arm / numArms) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				local armLen = rng:NextNumber(50, 120)
				local endX = cx + math.cos(angle) * armLen
				local endY = cy + math.sin(angle) * armLen
				local pts = generateBoltPath(cx, cy, endX, endY, 8, 14)
				local segs = drawBolt(LightningContainer, pts, 2, LIGHTNING_COLORS.primary, 0.05, 4)
				for _, s in ipairs(segs) do table.insert(allSegments, s) end
				if rng:NextNumber() > 0.5 then
					local midPt = pts[math.floor(#pts * 0.6)]
					if midPt then
						local subAngle = angle + rng:NextNumber(-0.6, 0.6)
						local subLen = armLen * 0.4
						local brSegs = drawBranch(LightningContainer, midPt.x, midPt.y, subAngle, subLen, 1, 5)
						for _, s in ipairs(brSegs) do table.insert(allSegments, s) end
					end
				end
			end
			local epicenterSpark = createSpark(LightningContainer, cx, cy)
			epicenterSpark.Size = UDim2.new(0, 8, 0, 8)
			table.insert(allSparks, epicenterSpark)

		else
			for bolt = 1, rng:NextInteger(2, 3) do
				local sx = rng:NextNumber(0, mainW)
				local sy = rng:NextNumber(-4, mainH * 0.15)
				local ex = sx + rng:NextNumber(-60, 60)
				local ey = rng:NextNumber(mainH * 0.6, mainH + 4)
				local pts = generateBoltPath(sx, sy, ex, ey, 12, 16)
				local segs = drawBolt(LightningContainer, pts, 1.8, LIGHTNING_COLORS.primary, 0.08 * bolt, 4)
				for _, s in ipairs(segs) do table.insert(allSegments, s) end
				for i = 1, rng:NextInteger(1, 2) do
					local branchIdx = math.floor(#pts * rng:NextNumber(0.2, 0.7))
					local branchPt = pts[branchIdx] or pts[math.floor(#pts / 2)]
					local angle = rng:NextNumber(-1.0, 1.0) + (math.pi / 2)
					local branchLen = rng:NextNumber(20, 45)
					local brSegs = drawBranch(LightningContainer, branchPt.x, branchPt.y, angle, branchLen, 1, 5)
					for _, s in ipairs(brSegs) do table.insert(allSegments, s) end
				end
			end
		end

		TweenService:Create(FlashOverlay, TweenInfo.new(0.04, Enum.EasingStyle.Linear), {BackgroundTransparency = 0.82}):Play()
		TweenService:Create(AmbientGlow, TweenInfo.new(0.06, Enum.EasingStyle.Linear), {BackgroundTransparency = 0.88}):Play()

		task.delay(0.06, function()
			TweenService:Create(FlashOverlay, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {BackgroundTransparency = 1}):Play()
			task.delay(0.09, function()
				if rng:NextNumber() > 0.5 then
					TweenService:Create(FlashOverlay, TweenInfo.new(0.03, Enum.EasingStyle.Linear), {BackgroundTransparency = 0.88}):Play()
					task.delay(0.04, function()
						TweenService:Create(FlashOverlay, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {BackgroundTransparency = 1}):Play()
					end)
				end
			end)
		end)

		task.delay(0.12, function()
			for _, seg in ipairs(allSegments) do
				if seg and seg.Parent then
					TweenService:Create(seg, TweenInfo.new(rng:NextNumber(0.15, 0.35), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
					for _, child in ipairs(seg:GetChildren()) do
						if child:IsA("Frame") then
							TweenService:Create(child, TweenInfo.new(rng:NextNumber(0.2, 0.4), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
						end
					end
				end
			end
			for _, sp in ipairs(allSparks) do
				if sp and sp.Parent then
					task.delay(rng:NextNumber(0.05, 0.2), function()
						if sp and sp.Parent then
							TweenService:Create(sp, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)}):Play()
							for _, child in ipairs(sp:GetChildren()) do
								if child:IsA("Frame") then
									TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
								end
							end
						end
					end)
				end
			end
		end)

		task.delay(0.5, function()
			TweenService:Create(AmbientGlow, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
		end)

		task.delay(0.8, function()
			clearLightningChildren(LightningContainer)
		end)
	end

	local function ambientCrackle()
		local mainW = Main.AbsoluteSize.X
		local mainH = Main.AbsoluteSize.Y
		if mainW < 10 or mainH < 10 then return end

		local sx = rng:NextNumber(mainW * 0.05, mainW * 0.95)
		local sy = rng:NextNumber(mainH * 0.05, mainH * 0.95)
		local numSegs = rng:NextInteger(2, 5)
		local segs = {}
		local cx, cy = sx, sy
		for i = 1, numSegs do
			local angle = rng:NextNumber(0, math.pi * 2)
			local len = rng:NextNumber(6, 18)
			local nx = cx + math.cos(angle) * len
			local ny = cy + math.sin(angle) * len
			local seg = createSegment(LightningContainer, cx, cy, nx, ny, 1, LIGHTNING_COLORS.spark, 0.2, 3)
			table.insert(segs, seg)
			cx, cy = nx, ny
		end
		local sp = createSpark(LightningContainer, sx, sy)
		task.delay(0.15, function()
			for _, seg in ipairs(segs) do
				if seg and seg.Parent then
					TweenService:Create(seg, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
					for _, child in ipairs(seg:GetChildren()) do
						if child:IsA("Frame") then
							TweenService:Create(child, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
						end
					end
				end
			end
			if sp and sp.Parent then
				TweenService:Create(sp, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 0)}):Play()
			end
		end)
		task.delay(0.4, function()
			for _, seg in ipairs(segs) do if seg and seg.Parent then seg:Destroy() end end
			if sp and sp.Parent then sp:Destroy() end
		end)
	end

	local function edgeArc()
		local mainW = Main.AbsoluteSize.X
		local mainH = Main.AbsoluteSize.Y
		if mainW < 10 or mainH < 10 then return end

		local edge = rng:NextInteger(1, 4)
		local sx, sy, ex, ey
		if edge == 1 then
			sx, sy = rng:NextNumber(0, mainW), 0
			ex, ey = sx + rng:NextNumber(-30, 30), rng:NextNumber(15, 40)
		elseif edge == 2 then
			sx, sy = rng:NextNumber(0, mainW), mainH
			ex, ey = sx + rng:NextNumber(-30, 30), mainH - rng:NextNumber(15, 40)
		elseif edge == 3 then
			sx, sy = 0, rng:NextNumber(0, mainH)
			ex, ey = rng:NextNumber(15, 40), sy + rng:NextNumber(-30, 30)
		else
			sx, sy = mainW, rng:NextNumber(0, mainH)
			ex, ey = mainW - rng:NextNumber(15, 40), sy + rng:NextNumber(-30, 30)
		end

		local pts = generateBoltPath(sx, sy, ex, ey, 5, 8)
		local segs = drawBolt(LightningContainer, pts, 1.5, LIGHTNING_COLORS.glow, 0.1, 3)

		local arcSpark = createSpark(LightningContainer, sx, sy)

		task.delay(0.1, function()
			for _, seg in ipairs(segs) do
				if seg and seg.Parent then
					TweenService:Create(seg, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
					for _, child in ipairs(seg:GetChildren()) do
						if child:IsA("Frame") then
							TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
						end
					end
				end
			end
			if arcSpark and arcSpark.Parent then
				TweenService:Create(arcSpark, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
			end
		end)
		task.delay(0.35, function()
			for _, seg in ipairs(segs) do if seg and seg.Parent then seg:Destroy() end end
			if arcSpark and arcSpark.Parent then arcSpark:Destroy() end
		end)
	end

	task.spawn(function()
		task.wait(1.5)
		while LightningContainer and LightningContainer.Parent do
			if _G.DiceLightningEnabled ~= false then
				fireStrike()
				task.wait(rng:NextNumber(3.5, 7.0))

				if _G.DiceLightningEnabled ~= false and rng:NextNumber() > 0.3 then
					for _ = 1, rng:NextInteger(1, 3) do
						if _G.DiceLightningEnabled == false then break end
						ambientCrackle()
						task.wait(rng:NextNumber(0.3, 0.8))
					end
				end

				if _G.DiceLightningEnabled ~= false and rng:NextNumber() > 0.4 then
					edgeArc()
				end

				task.wait(rng:NextNumber(1.0, 3.0))
			else
				task.wait(1)
			end
		end
	end)

	_G.DiceLightningEnabled = true
	_G.DiceFireLightning = fireStrike
end
-- ═══════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════
-- HEADER — title block on the left, player card on the right, and
-- the window controls stacked beside it
-- ═══════════════════════════════════════════════════════════════
do
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
TopBar.BackgroundTransparency = 0.16
TopBar.BorderSizePixel = 0
TopBar.Position = UDim2.new(0, 10, 0, 10)
TopBar.Size = UDim2.new(1, -20, 0, 86)
TopBar.Active = true
TopBar.ZIndex = 5
TopBar.Parent = Main
corner(TopBar, 12)
stroke(TopBar, COLORS.strokeSoft, 1, 0.5)
-- The header covers the old bare-Main drag area, so make it a handle.
makeDraggable(Main, TopBar)
-- Hairline along the top edge of the header, the one bright line on
-- the whole panel.
local TopGlow = Instance.new("Frame")
TopGlow.Name = "TopGlow"
TopGlow.BackgroundColor3 = COLORS.accent
TopGlow.BackgroundTransparency = 0.25
TopGlow.BorderSizePixel = 0
TopGlow.AnchorPoint = Vector2.new(0.5, 0)
TopGlow.Position = UDim2.new(0.5, 0, 0, 0)
TopGlow.Size = UDim2.new(0.55, 0, 0, 2)
TopGlow.ZIndex = 7
TopGlow.Parent = TopBar
corner(TopGlow, 1)
do
local fade = Instance.new("UIGradient")
fade.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 1),
NumberSequenceKeypoint.new(0.5, 0),
NumberSequenceKeypoint.new(1, 1),
})
fade.Parent = TopGlow
end
local TitleDieA, setTitleDieA = makeDie(TopBar, 16, 5, false)
TitleDieA.Name = "TitleDieA"
TitleDieA.Position = UDim2.new(0, 14, 0, 18)
TitleDieA.Rotation = -9
local TitleDieB, setTitleDieB = makeDie(TopBar, 16, 2, true)
TitleDieB.Name = "TitleDieB"
TitleDieB.Position = UDim2.new(0, 35, 0, 18)
TitleDieB.Rotation = 8
-- Re-rolled whenever you change tab, so the pair is never dead weight.
function rollTitleDice()
task.spawn(function()
for _ = 1, 7 do
setTitleDieA(math.random(1, 6))
setTitleDieB(math.random(1, 6))
task.wait(0.045)
end
end)
end
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(0, 48, 0, 24)
Title.Position = UDim2.new(0, 56, 0, 15)
Title.Text = "DICE"
Title.TextColor3 = COLORS.white
Title.TextStrokeTransparency = 0.6
Title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 19
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6
Title.Parent = TopBar
local TitleSub = Instance.new("TextLabel")
TitleSub.Name = "TitleSub"
TitleSub.BackgroundTransparency = 1
TitleSub.Size = UDim2.new(0, 90, 0, 24)
TitleSub.Position = UDim2.new(0, 104, 0, 15)
TitleSub.Text = "DUELS"
TitleSub.TextColor3 = COLORS.accentDim
TitleSub.TextStrokeTransparency = 0.7
TitleSub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
TitleSub.Font = Enum.Font.GothamBlack
TitleSub.TextSize = 19
TitleSub.TextXAlignment = Enum.TextXAlignment.Left
TitleSub.ZIndex = 6
TitleSub.Parent = TopBar
local Discord = Instance.new("TextLabel")
Discord.Name = "Discord"
Discord.BackgroundTransparency = 1
Discord.Position = UDim2.new(0, 15, 0, 42)
Discord.Size = UDim2.new(0, 170, 0, 14)
Discord.Text = "discord.gg/qgwhrFZXd"
Discord.TextColor3 = COLORS.textDim
Discord.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
Discord.TextStrokeTransparency = 0.45
Discord.Font = Enum.Font.GothamSemibold
Discord.TextSize = 11
Discord.TextXAlignment = Enum.TextXAlignment.Left
Discord.ZIndex = 6
Discord.Parent = TopBar
-- ═══════════════════════════════════════════════════════════════
-- PLAYER CARD — headshot, display name, @handle and a live dot
-- ═══════════════════════════════════════════════════════════════
local PlayerCard = Instance.new("Frame")
PlayerCard.Name = "PlayerCard"
PlayerCard.BackgroundColor3 = COLORS.row2
PlayerCard.BackgroundTransparency = 0.2
PlayerCard.BorderSizePixel = 0
PlayerCard.AnchorPoint = Vector2.new(1, 0.5)
PlayerCard.Position = UDim2.new(1, -46, 0.5, 0)
PlayerCard.Size = UDim2.new(0, 152, 0, 58)
PlayerCard.ZIndex = 6
PlayerCard.Parent = TopBar
corner(PlayerCard, 11)
stroke(PlayerCard, COLORS.strokeSoft, 1, 0.42)
local Avatar = Instance.new("ImageLabel")
Avatar.Name = "Avatar"
Avatar.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
Avatar.BackgroundTransparency = 0.15
Avatar.BorderSizePixel = 0
-- rbxthumb resolves on the client without the yielding thumbnail call.
Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LP.UserId) .. "&w=150&h=150"
Avatar.ScaleType = Enum.ScaleType.Fit
Avatar.Position = UDim2.new(0, 7, 0.5, -19)
Avatar.Size = UDim2.new(0, 38, 0, 38)
Avatar.ZIndex = 7
Avatar.Parent = PlayerCard
corner(Avatar, 999)
stroke(Avatar, COLORS.accent, 1.2, 0.35)
local OnlineDot = Instance.new("Frame")
OnlineDot.Name = "OnlineDot"
OnlineDot.BackgroundColor3 = COLORS.accent
OnlineDot.BorderSizePixel = 0
OnlineDot.Position = UDim2.new(0, 36, 0.5, 8)
OnlineDot.Size = UDim2.new(0, 9, 0, 9)
OnlineDot.ZIndex = 8
OnlineDot.Parent = PlayerCard
corner(OnlineDot, 999)
stroke(OnlineDot, Color3.fromRGB(12, 12, 14), 1.5, 0)
local PlayerName = Instance.new("TextLabel")
PlayerName.Name = "PlayerName"
PlayerName.BackgroundTransparency = 1
PlayerName.Position = UDim2.new(0, 52, 0.5, -18)
PlayerName.Size = UDim2.new(1, -60, 0, 15)
PlayerName.Text = tostring(LP.DisplayName)
PlayerName.TextColor3 = COLORS.white
PlayerName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
PlayerName.TextStrokeTransparency = 0.4
PlayerName.Font = Enum.Font.GothamBold
PlayerName.TextSize = 11
PlayerName.TextXAlignment = Enum.TextXAlignment.Left
PlayerName.TextTruncate = Enum.TextTruncate.AtEnd
PlayerName.ZIndex = 7
PlayerName.Parent = PlayerCard
local PlayerHandle = Instance.new("TextLabel")
PlayerHandle.Name = "PlayerHandle"
PlayerHandle.BackgroundTransparency = 1
PlayerHandle.Position = UDim2.new(0, 52, 0.5, -2)
PlayerHandle.Size = UDim2.new(1, -60, 0, 13)
PlayerHandle.Text = "@" .. tostring(LP.Name)
PlayerHandle.TextColor3 = COLORS.textDim
PlayerHandle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
PlayerHandle.TextStrokeTransparency = 0.5
PlayerHandle.Font = Enum.Font.GothamSemibold
PlayerHandle.TextSize = 9
PlayerHandle.TextXAlignment = Enum.TextXAlignment.Left
PlayerHandle.TextTruncate = Enum.TextTruncate.AtEnd
PlayerHandle.ZIndex = 7
PlayerHandle.Parent = PlayerCard
local CardUnderline = Instance.new("Frame")
CardUnderline.Name = "CardUnderline"
CardUnderline.BackgroundColor3 = COLORS.accent
CardUnderline.BackgroundTransparency = 0.45
CardUnderline.BorderSizePixel = 0
CardUnderline.Position = UDim2.new(0, 52, 0.5, 14)
CardUnderline.Size = UDim2.new(1, -66, 0, 1)
CardUnderline.ZIndex = 7
CardUnderline.Parent = PlayerCard
Close = Instance.new("TextButton")
Close.Name = "Close"
Close.BackgroundColor3 = Color3.fromRGB(246, 246, 250)
Close.BackgroundTransparency = 0.04
Close.Text = "–"
Close.TextColor3 = Color3.fromRGB(12, 12, 14)
Close.TextSize = 18
Close.Font = Enum.Font.GothamBold
Close.Size = UDim2.new(0, 30, 0, 24)
Close.Position = UDim2.new(1, -38, 0.5, -26)
Close.AutoButtonColor = false
Close.ZIndex = 6
Close.Parent = TopBar
corner(Close, 7)
stroke(Close, Color3.fromRGB(255, 255, 255), 1, 0.45)
DiceLockTopButton = Instance.new("TextButton")
DiceLockTopButton.Name = "LockGUI"
DiceLockTopButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DiceLockTopButton.BackgroundTransparency = 0.28
DiceLockTopButton.TextColor3 = COLORS.white
DiceLockTopButton.TextSize = 8
DiceLockTopButton.Font = Enum.Font.GothamBlack
DiceLockTopButton.Size = UDim2.new(0, 30, 0, 24)
DiceLockTopButton.Position = UDim2.new(1, -38, 0.5, 2)
DiceLockTopButton.AutoButtonColor = false
DiceLockTopButton.ZIndex = 6
DiceLockTopButton.Parent = TopBar
corner(DiceLockTopButton, 7)
stroke(DiceLockTopButton, COLORS.stroke, 1, 0.35)
end
function DiceUpdateGuiLockVisual()
if DiceLockTopButton then
DiceLockTopButton.Text = (_G.DiceGuiLocked == true) and "UNLOCK" or "LOCK"
DiceLockTopButton.BackgroundTransparency = (_G.DiceGuiLocked == true) and 0.08 or 0.28
local st = DiceLockTopButton:FindFirstChildOfClass("UIStroke")
if st then
st.Transparency = (_G.DiceGuiLocked == true) and 0.08 or 0.35
st.Color = (_G.DiceGuiLocked == true) and Color3.fromRGB(255,255,255) or COLORS.stroke
end
end
if setLockGuiVisual then pcall(setLockGuiVisual, _G.DiceGuiLocked == true) end
end
DiceLockTopButton.Activated:Connect(function()
_G.DiceGuiLocked = not (_G.DiceGuiLocked == true)
DiceUpdateGuiLockVisual()
saveDiceConfig()
end)
DiceUpdateGuiLockVisual()
-- ═══════════════════════════════════════════════════════════════
-- SIDEBAR — narrow navigation rail: a die badge per tab with its
-- name beside it, and the scrolling content pane alongside
-- ═══════════════════════════════════════════════════════════════
do
local SIDEBAR_WIDTH = 108
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
Sidebar.BackgroundTransparency = 0.34
Sidebar.BorderSizePixel = 0
Sidebar.Position = UDim2.new(0, 10, 0, 104)
Sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -114)
Sidebar.ZIndex = 3
Sidebar.Parent = Main
corner(Sidebar, 12)
stroke(Sidebar, COLORS.strokeSoft, 1, 0.5)
local NavCaption = Instance.new("TextLabel")
NavCaption.Name = "NavCaption"
NavCaption.BackgroundTransparency = 1
NavCaption.Position = UDim2.new(0, 11, 0, 9)
NavCaption.Size = UDim2.new(1, -22, 0, 12)
NavCaption.Text = "NAVIGATION"
NavCaption.TextColor3 = COLORS.textDim
NavCaption.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
NavCaption.TextStrokeTransparency = 0.5
NavCaption.Font = Enum.Font.GothamBold
NavCaption.TextSize = 8
NavCaption.TextXAlignment = Enum.TextXAlignment.Left
NavCaption.ZIndex = 4
NavCaption.Parent = Sidebar
Tabs = Instance.new("Frame")
Tabs.Name = "Tabs"
Tabs.BackgroundTransparency = 1
Tabs.Position = UDim2.new(0, 8, 0, 26)
Tabs.Size = UDim2.new(1, -16, 1, -60)
Tabs.ZIndex = 3
Tabs.Parent = Sidebar
local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Vertical
TabLayout.Padding = UDim.new(0, 6)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = Tabs
-- Credit strip along the foot of the rail.
local MadeBy = Instance.new("TextLabel")
MadeBy.Name = "MadeBy"
MadeBy.BackgroundTransparency = 1
MadeBy.AnchorPoint = Vector2.new(0.5, 1)
MadeBy.Position = UDim2.new(0.5, 0, 1, -10)
MadeBy.Size = UDim2.new(1, -16, 0, 12)
MadeBy.Text = "DICE DUELS"
MadeBy.TextColor3 = COLORS.textDim
MadeBy.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
MadeBy.TextStrokeTransparency = 0.45
MadeBy.Font = Enum.Font.GothamBold
MadeBy.TextSize = 8
MadeBy.TextXAlignment = Enum.TextXAlignment.Center
MadeBy.ZIndex = 4
MadeBy.Parent = Sidebar
-- Content pane: the rows need a ground of their own, otherwise the
-- backdrop dice read straight through the gaps between them.
local ContentPane = Instance.new("Frame")
ContentPane.Name = "ContentPane"
ContentPane.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
ContentPane.BackgroundTransparency = 0.34
ContentPane.BorderSizePixel = 0
ContentPane.Position = UDim2.new(0, SIDEBAR_WIDTH + 18, 0, 104)
ContentPane.Size = UDim2.new(1, -(SIDEBAR_WIDTH + 28), 1, -114)
ContentPane.ZIndex = 3
ContentPane.Parent = Main
corner(ContentPane, 12)
stroke(ContentPane, COLORS.strokeSoft, 1, 0.5)
-- Page heading: accent bar, the tab's name, and a die that re-rolls
-- with it — the panel's answer to the reference's weather glyph.
local PageAccent = Instance.new("Frame")
PageAccent.Name = "PageAccent"
PageAccent.BackgroundColor3 = COLORS.accent
PageAccent.BackgroundTransparency = 0.15
PageAccent.BorderSizePixel = 0
PageAccent.Position = UDim2.new(0, 12, 0, 14)
PageAccent.Size = UDim2.new(0, 3, 0, 16)
PageAccent.ZIndex = 6
PageAccent.Parent = ContentPane
corner(PageAccent, 2)
PageTitle = Instance.new("TextLabel")
PageTitle.Name = "PageTitle"
PageTitle.BackgroundTransparency = 1
PageTitle.Position = UDim2.new(0, 22, 0, 13)
PageTitle.Size = UDim2.new(1, -60, 0, 18)
PageTitle.Text = "MOVEMENT CONFIGURATION"
PageTitle.TextColor3 = COLORS.white
PageTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
PageTitle.TextStrokeTransparency = 0.4
PageTitle.Font = Enum.Font.GothamBlack
PageTitle.TextSize = 12
PageTitle.TextXAlignment = Enum.TextXAlignment.Left
PageTitle.TextTruncate = Enum.TextTruncate.AtEnd
PageTitle.ZIndex = 6
PageTitle.Parent = ContentPane
local PageDie
PageDie, setPageDieFace = makeDie(ContentPane, 22, 6, false)
PageDie.Name = "PageDie"
PageDie.AnchorPoint = Vector2.new(1, 0)
PageDie.Position = UDim2.new(1, -12, 0, 11)
PageDie.Rotation = 10
local PageDivider = Instance.new("Frame")
PageDivider.Name = "PageDivider"
PageDivider.BackgroundColor3 = COLORS.stroke
PageDivider.BackgroundTransparency = 0.5
PageDivider.BorderSizePixel = 0
PageDivider.Position = UDim2.new(0, 12, 0, 40)
PageDivider.Size = UDim2.new(1, -24, 0, 1)
PageDivider.ZIndex = 6
PageDivider.Parent = ContentPane
Content = Instance.new("Frame")
Content.Name = "Content"
Content.BackgroundTransparency = 1
Content.Position = UDim2.new(0, SIDEBAR_WIDTH + 28, 0, 152)
Content.Size = UDim2.new(1, -(SIDEBAR_WIDTH + 46), 1, -164)
Content.ZIndex = 3
Content.Parent = Main
end
local pages = {}
local tabButtons = {}
local tabNames = {"MOVEMENT", "COMBAT", "KEYBINDS", "VISUALS", "SETTINGS"}
local activeTab = "MOVEMENT"
function addPage(name)
local page = Instance.new("ScrollingFrame")
page.Name = name
page.BackgroundTransparency = 1
page.BorderSizePixel = 0
page.ScrollBarThickness = 3
page.ScrollBarImageColor3 = Color3.fromRGB(215, 215, 220)
page.ScrollBarImageTransparency = 0.35
page.CanvasSize = UDim2.new(0, 0, 0, 0)
page.AutomaticCanvasSize = Enum.AutomaticSize.Y
page.Size = UDim2.new(1, 0, 1, 0)
page.ZIndex = 3
page.Visible = false
page.Parent = Content
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 7)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = page
pages[name] = page
return page
end
function setTab(name)
activeTab = name
for pageName, page in pairs(pages) do
page.Visible = pageName == name
end
if PageTitle then PageTitle.Text = name .. " CONFIGURATION" end
if setPageDieFace then setPageDieFace(math.random(1, 6)) end
if rollTitleDice then rollTitleDice() end
if rollBackdropDice then rollBackdropDice() end
for tabName, btn in pairs(tabButtons) do
local on = tabName == name
btn.TextColor3 = on and COLORS.white or COLORS.textDim
tween(btn, {BackgroundTransparency = on and 0.22 or 0.68})
local st = btn:FindFirstChildOfClass("UIStroke")
if st then
st.Transparency = on and 0.15 or 0.6
st.Color = on and COLORS.accent or COLORS.stroke
end
local accent = btn:FindFirstChild("Accent")
if accent then
tween(accent, {
BackgroundTransparency = on and 0 or 1,
Size = on and UDim2.new(0, 3, 0, 24) or UDim2.new(0, 3, 0, 0)
})
end
local badge = btn:FindFirstChild("Badge")
if badge then
tween(badge, {BackgroundTransparency = on and 0.05 or 0.2})
local bst = badge:FindFirstChildOfClass("UIStroke")
if bst then
bst.Color = on and COLORS.accent or COLORS.stroke
bst.Transparency = on and 0.2 or 0.5
end
end
end
end
for i, name in ipairs(tabNames) do
addPage(name)
local btn = Instance.new("TextButton")
btn.Name = name
btn.Size = UDim2.new(1, 0, 0, 52)
btn.BackgroundColor3 = Color3.fromRGB(22, 22, 25)
btn.BackgroundTransparency = 0.68
btn.BorderSizePixel = 0
btn.Text = name
btn.TextColor3 = COLORS.textDim
btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
btn.TextStrokeTransparency = 0.35
btn.TextSize = 8
btn.Font = Enum.Font.GothamBlack
btn.TextXAlignment = Enum.TextXAlignment.Left
btn.TextTruncate = Enum.TextTruncate.AtEnd
btn.AutoButtonColor = false
btn.ZIndex = 4
btn.Parent = Tabs
corner(btn, 9)
stroke(btn, COLORS.stroke, 1, 0.6)
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 38)
pad.Parent = btn
-- Each tab carries its own face, one through five, in a badge tile
-- the way the reference rail carries two-letter codes.
local badge = Instance.new("Frame")
badge.Name = "Badge"
badge.BackgroundColor3 = COLORS.accentSoft
badge.BackgroundTransparency = 0.2
badge.BorderSizePixel = 0
badge.Position = UDim2.new(0, -30, 0.5, -13)
badge.Size = UDim2.new(0, 26, 0, 26)
badge.ZIndex = 5
badge.Parent = btn
corner(badge, 8)
stroke(badge, COLORS.stroke, 1, 0.5)
local tabDie = makeDie(badge, 16, i, false)
tabDie.Name = "TabDie"
tabDie.Position = UDim2.new(0.5, -8, 0.5, -8)
tabDie.Rotation = (i % 2 == 0) and 7 or -7
local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.BackgroundColor3 = COLORS.accent
accent.BackgroundTransparency = 1
accent.BorderSizePixel = 0
accent.AnchorPoint = Vector2.new(0, 0.5)
accent.Position = UDim2.new(0, -36, 0.5, 0)
accent.Size = UDim2.new(0, 3, 0, 0)
accent.ZIndex = 7
accent.Parent = btn
corner(accent, 2)
tabButtons[name] = btn
btn.MouseButton1Click:Connect(function()
setTab(name)
end)
end
function section(parent, text, order)
local holder = Instance.new("Frame")
holder.Name = text
holder.BackgroundTransparency = 1
holder.Size = UDim2.new(1, -6, 0, 24)
holder.LayoutOrder = order
holder.ZIndex = 8
holder.Parent = parent
local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Text = text
label.TextColor3 = Color3.fromRGB(245, 245, 250)
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0.22
label.TextSize = 11
label.Font = Enum.Font.GothamBlack
label.TextXAlignment = Enum.TextXAlignment.Left
label.Position = UDim2.new(0, 2, 0, 0)
label.Size = UDim2.new(1, -2, 0, 15)
label.ZIndex = 8
label.Parent = holder
local underline = Instance.new("Frame")
underline.Name = "Underline"
underline.BackgroundColor3 = COLORS.accent
underline.BackgroundTransparency = 0.3
underline.BorderSizePixel = 0
underline.Size = UDim2.new(1, -2, 0, 1)
underline.Position = UDim2.new(0, 2, 0, 20)
underline.ZIndex = 8
underline.Parent = holder
local fade = Instance.new("UIGradient")
fade.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0),
NumberSequenceKeypoint.new(0.75, 0.5),
NumberSequenceKeypoint.new(1, 1),
})
fade.Parent = underline
return holder
end
function baseRow(parent, labelText, order)
local row = Instance.new("Frame")
row.Name = labelText
row.BackgroundColor3 = COLORS.row
row.BackgroundTransparency = 0.3
row.Size = UDim2.new(1, -4, 0, 36)
row.BorderSizePixel = 0
row.LayoutOrder = order
row.ZIndex = 4
row.Parent = parent
corner(row, 10)
stroke(row, COLORS.strokeSoft, 1.15, 0.38)
local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Text = labelText
label.TextColor3 = Color3.fromRGB(245, 245, 255)
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0.25
label.TextSize = 12
label.Font = Enum.Font.GothamSemibold
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextTruncate = Enum.TextTruncate.AtEnd
label.Position = UDim2.new(0, 12, 0, 0)
-- Leaves room for the widest right-hand control (the value pill).
label.Size = UDim2.new(1, -90, 1, 0)
label.ZIndex = 5
label.Parent = row
row.MouseEnter:Connect(function()
tween(row, {BackgroundTransparency = 0.22})
end)
row.MouseLeave:Connect(function()
tween(row, {BackgroundTransparency = 0.3})
end)
return row
end
function textboxRow(parent, labelText, value, order)
local row = baseRow(parent, labelText, order)
local box = Instance.new("TextBox")
box.Name = "ValueBox"
box.BackgroundColor3 = COLORS.accentSoft
box.BackgroundTransparency = 0.18
box.Text = tostring(value or "")
box.TextColor3 = COLORS.white
box.TextSize = 12
box.Font = Enum.Font.GothamSemibold
box.ClearTextOnFocus = false
box.Size = UDim2.new(0, 62, 0, 26)
box.Position = UDim2.new(1, -72, 0.5, -13)
box.BorderSizePixel = 0
box.ZIndex = 6
box.Parent = row
corner(box, 8)
stroke(box, COLORS.strokeSoft, 1, 0.45)
return row, box
end
function toggleRow(parent, labelText, default, order)
local row = baseRow(parent, labelText, order)
local button = Instance.new("TextButton")
button.Name = "ToggleButton"
button.BackgroundTransparency = 1
button.Text = ""
button.Size = UDim2.new(1, 0, 1, 0)
button.Position = UDim2.new(0, 0, 0, 0)
button.AutoButtonColor = false
button.ZIndex = 7
button.Parent = row
local track = Instance.new("Frame")
track.Name = "Track"
track.BackgroundColor3 = COLORS.toggleBg
track.BackgroundTransparency = 0.2
track.Size = UDim2.new(0, 34, 0, 18)
track.Position = UDim2.new(1, -44, 0.5, -9)
track.BorderSizePixel = 0
track.ZIndex = 5
track.Parent = button
corner(track, 9)
stroke(track, COLORS.strokeSoft, 1, 0.45)
local knob = Instance.new("Frame")
knob.Name = "Knob"
knob.BackgroundColor3 = COLORS.knob
knob.Size = UDim2.new(0, 13, 0, 13)
knob.Position = default and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
knob.BorderSizePixel = 0
knob.ZIndex = 6
knob.Parent = track
corner(knob, 999)
local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.BackgroundColor3 = COLORS.white
shine.BackgroundTransparency = 0.72
shine.Size = UDim2.new(1, -4, 0, 4)
shine.Position = UDim2.new(0, 2, 0, 2)
shine.BorderSizePixel = 0
shine.ZIndex = 7
shine.Parent = knob
corner(shine, 4)
local state = default and true or false
local trackStroke = track:FindFirstChildOfClass("UIStroke")
local rowStroke = row:FindFirstChildOfClass("UIStroke")
local function setVisual(on)
state = on and true or false
tween(knob, {
Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
-- White track, dark knob when on: the only contrast a monochrome
-- switch has left once the accent stopped being a colour.
BackgroundColor3 = state and Color3.fromRGB(16, 16, 18) or COLORS.knob
})
tween(track, {
BackgroundTransparency = state and 0.03 or 0.2,
BackgroundColor3 = state and COLORS.accent or COLORS.toggleBg
})
if trackStroke then
tween(trackStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.05 or 0.45,
Thickness = state and 1.25 or 1
})
end
if rowStroke then
tween(rowStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.12 or 0.38,
Thickness = state and 1.25 or 1.15
})
end
tween(row, {BackgroundTransparency = state and 0.16 or 0.3})
end
setVisual(state)
button.Activated:Connect(function()
end)
return row, setVisual
end
_G.DiceSyncToggleVisuals = function()
pcall(function() if setAutoStealVisual then setAutoStealVisual(autoStealEnabled == true) end end)
pcall(function() if setInfJumpVisual then setInfJumpVisual(infJumpEnabled == true) end end)
pcall(function() if setAntiRagdollVisual then setAntiRagdollVisual(antiRagdollEnabled == true) end end)
pcall(function() if setAutoCarrySpeedVisual then setAutoCarrySpeedVisual(autoCarrySpeedEnabled == true) end end)
pcall(function() if setAutoTPVisual then setAutoTPVisual(autoTPEnabled == true) end end)
pcall(function() if setAutoResetOnMedVisual then setAutoResetOnMedVisual(autoResetOnMedEnabled == true) end end)
end
_G.DiceActionToggleRow = function(parent, labelText, default, order)
local row = baseRow(parent, labelText, order)
local button = Instance.new("TextButton")
button.Name = "ToggleButton"
button.BackgroundTransparency = 1
button.Text = ""
button.Size = UDim2.new(1, 0, 1, 0)
button.Position = UDim2.new(0, 0, 0, 0)
button.AutoButtonColor = false
button.ZIndex = 7
button.Parent = row
local track = Instance.new("Frame")
track.Name = "Track"
track.BackgroundColor3 = COLORS.toggleBg
track.BackgroundTransparency = 0.2
track.Size = UDim2.new(0, 34, 0, 18)
track.Position = UDim2.new(1, -44, 0.5, -9)
track.BorderSizePixel = 0
track.ZIndex = 5
track.Parent = button
corner(track, 9)
stroke(track, COLORS.strokeSoft, 1, 0.45)
local knob = Instance.new("Frame")
knob.Name = "Knob"
knob.BackgroundColor3 = COLORS.knob
knob.Size = UDim2.new(0, 13, 0, 13)
knob.Position = default and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
knob.BorderSizePixel = 0
knob.ZIndex = 6
knob.Parent = track
corner(knob, 999)
local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.BackgroundColor3 = COLORS.white
shine.BackgroundTransparency = 0.72
shine.Size = UDim2.new(1, -4, 0, 4)
shine.Position = UDim2.new(0, 2, 0, 2)
shine.BorderSizePixel = 0
shine.ZIndex = 7
shine.Parent = knob
corner(shine, 4)
local trackStroke = track:FindFirstChildOfClass("UIStroke")
local rowStroke = row:FindFirstChildOfClass("UIStroke")
local function setVisual(on)
local state = on and true or false
tween(knob, {
Position = state and UDim2.new(1, -16, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
-- White track, dark knob when on: the only contrast a monochrome
-- switch has left once the accent stopped being a colour.
BackgroundColor3 = state and Color3.fromRGB(16, 16, 18) or COLORS.knob
})
tween(track, {
BackgroundTransparency = state and 0.03 or 0.2,
BackgroundColor3 = state and COLORS.accent or COLORS.toggleBg
})
if trackStroke then
tween(trackStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.05 or 0.45,
Thickness = state and 1.25 or 1
})
end
if rowStroke then
tween(rowStroke, {
Color = state and COLORS.accent or COLORS.strokeSoft,
Transparency = state and 0.12 or 0.38,
Thickness = state and 1.25 or 1.15
})
end
tween(row, {BackgroundTransparency = state and 0.16 or 0.3})
end
setVisual(default)
return row, setVisual, button
end
function dropdownRow(parent, labelText, value, order)
local row = baseRow(parent, labelText, order)
local select = Instance.new("TextButton")
select.Name = "Dropdown"
select.BackgroundColor3 = COLORS.accentSoft
select.BackgroundTransparency = 0.18
select.Text = tostring(value or "None") .. "  ▼"
select.TextColor3 = COLORS.white
select.TextSize = 11
select.Font = Enum.Font.GothamSemibold
select.Size = UDim2.new(0, 70, 0, 24)
select.Position = UDim2.new(1, -80, 0.5, -12)
select.BorderSizePixel = 0
select.ZIndex = 6
select.Parent = row
corner(select, 7)
stroke(select, COLORS.strokeSoft, 1, 0.45)
return row, select
end
local animationPackValueLabel = nil
function refreshAnimationPackRow()
if animationPackValueLabel then
animationPackValueLabel.Text = selectedAnimationPack
end
end
function animationPackRow(parent, order)
local row = baseRow(parent, "Animation Pack", order)
row.Size = UDim2.new(1, -4, 0, 42)
local label = row:FindFirstChild("Label")
if label then
label.Text = "Animation Pack"
label.Size = UDim2.new(0, 112, 1, 0)
label.TextSize = 11
end
local left = Instance.new("TextButton")
left.Name = "LeftArrow"
left.BackgroundColor3 = COLORS.accentSoft
left.BackgroundTransparency = 0.18
left.Text = "<"
left.TextColor3 = COLORS.white
left.TextSize = 12
left.Font = Enum.Font.GothamSemibold
left.Size = UDim2.new(0, 42, 0, 28)
left.Position = UDim2.new(1, -156, 0.5, -14)
left.BorderSizePixel = 0
left.ZIndex = 6
left.Parent = row
corner(left, 8)
stroke(left, COLORS.strokeSoft, 1, 0.45)
animationPackValueLabel = Instance.new("TextLabel")
animationPackValueLabel.Name = "AnimationPackValue"
animationPackValueLabel.BackgroundTransparency = 1
animationPackValueLabel.Text = selectedAnimationPack
animationPackValueLabel.TextColor3 = COLORS.white
animationPackValueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
animationPackValueLabel.TextStrokeTransparency = 0.25
animationPackValueLabel.TextSize = 11
animationPackValueLabel.Font = Enum.Font.GothamSemibold
animationPackValueLabel.TextXAlignment = Enum.TextXAlignment.Center
animationPackValueLabel.Size = UDim2.new(0, 62, 1, 0)
animationPackValueLabel.Position = UDim2.new(1, -112, 0, 0)
animationPackValueLabel.ZIndex = 6
animationPackValueLabel.Parent = row
local right = Instance.new("TextButton")
right.Name = "RightArrow"
right.BackgroundColor3 = COLORS.accentSoft
right.BackgroundTransparency = 0.18
right.Text = ">"
right.TextColor3 = COLORS.white
right.TextSize = 12
right.Font = Enum.Font.GothamSemibold
right.Size = UDim2.new(0, 42, 0, 28)
right.Position = UDim2.new(1, -48, 0.5, -14)
right.BorderSizePixel = 0
right.ZIndex = 6
right.Parent = row
corner(right, 8)
stroke(right, COLORS.strokeSoft, 1, 0.45)
local function setPackIndex(nextIndex)
if nextIndex < 1 then nextIndex = #AnimationPackList end
if nextIndex > #AnimationPackList then nextIndex = 1 end
AnimationPackIndex = nextIndex
selectedAnimationPack = AnimationPackList[AnimationPackIndex]
refreshAnimationPackRow()
applyAnimationPack(selectedAnimationPack)
if saveDiceConfig then pcall(saveDiceConfig) end
end
left.MouseButton1Click:Connect(function()
setPackIndex(AnimationPackIndex - 1)
end)
right.MouseButton1Click:Connect(function()
setPackIndex(AnimationPackIndex + 1)
end)
return row
end
function keyName(key)
if not key then return "None" end
local name = tostring(key):gsub("Enum.KeyCode.", "")
name = name:gsub("Button", "BTN ")
name = name:gsub("DPad", "DPad ")
return name
end
function refreshSpeedKeybindButton(keyId)
local btn = speedKeybindButtons[keyId]
if btn then
if listeningForSpeedKey == keyId then
btn.Text = "Press..."
else
btn.Text = keyName(speedKeybinds[keyId])
end
end
end
function refreshAllSpeedKeybinds()
for keyId in pairs(speedKeybindButtons) do
refreshSpeedKeybindButton(keyId)
end
end
function refreshTPDownKeybind()
if tpDownKeybindButton then
tpDownKeybindButton.Text = listeningForTPDownKey and "Press..." or keyName(tpDownKeybind)
end
end
function tpDownKeybindRow(parent, order)
local row = baseRow(parent, "TP Down", order)
local btn = Instance.new("TextButton")
btn.Name = "TPDownKeybindButton"
btn.BackgroundColor3 = COLORS.accentSoft
btn.BackgroundTransparency = 0.18
btn.Text = keyName(tpDownKeybind)
btn.TextColor3 = COLORS.white
btn.TextSize = 11
btn.Font = Enum.Font.GothamSemibold
btn.Size = UDim2.new(0, 56, 0, 24)
btn.Position = UDim2.new(1, -64, 0.5, -12)
btn.BorderSizePixel = 0
btn.ZIndex = 6
btn.AutoButtonColor = false
btn.Parent = row
corner(btn, 7)
stroke(btn, COLORS.strokeSoft, 1, 0.45)
local clearBtn = Instance.new("TextButton")
clearBtn.Name = "ClearKeybindButton"
clearBtn.BackgroundColor3 = COLORS.accentSoft
clearBtn.BackgroundTransparency = 0.18
clearBtn.Text = "×"
clearBtn.TextColor3 = COLORS.white
clearBtn.TextSize = 14
clearBtn.Font = Enum.Font.GothamBlack
clearBtn.Size = UDim2.new(0, 22, 0, 24)
clearBtn.Position = UDim2.new(1, -90, 0.5, -12)
clearBtn.BorderSizePixel = 0
clearBtn.ZIndex = 6
clearBtn.AutoButtonColor = false
clearBtn.Parent = row
corner(clearBtn, 7)
stroke(clearBtn, COLORS.strokeSoft, 1, 0.45)
tpDownKeybindButton = btn
btn.Activated:Connect(function()
listeningForSpeedKey = nil
listeningForTPDownKey = true
keybindListenStartedAt = tick()
refreshAllSpeedKeybinds()
refreshTPDownKeybind()
end)
clearBtn.Activated:Connect(function()
listeningForSpeedKey = nil
listeningForTPDownKey = false
tpDownKeybind = nil
if tpDownKeybindButton then tpDownKeybindButton.Text = "None" end
refreshAllSpeedKeybinds()
refreshTPDownKeybind()
saveDiceConfig()
end)
return row, btn
end
function speedKeybindRow(parent, labelText, keyId, order)
local row = baseRow(parent, labelText, order)
local btn = Instance.new("TextButton")
btn.Name = "KeybindButton"
btn.BackgroundColor3 = COLORS.accentSoft
btn.BackgroundTransparency = 0.18
btn.Text = keyName(speedKeybinds[keyId])
btn.TextColor3 = COLORS.white
btn.TextSize = 11
btn.Font = Enum.Font.GothamSemibold
btn.Size = UDim2.new(0, 56, 0, 24)
btn.Position = UDim2.new(1, -64, 0.5, -12)
btn.BorderSizePixel = 0
btn.ZIndex = 6
btn.AutoButtonColor = false
btn.Parent = row
corner(btn, 7)
stroke(btn, COLORS.strokeSoft, 1, 0.45)
local clearBtn = Instance.new("TextButton")
clearBtn.Name = "ClearKeybindButton"
clearBtn.BackgroundColor3 = COLORS.accentSoft
clearBtn.BackgroundTransparency = 0.18
clearBtn.Text = "×"
clearBtn.TextColor3 = COLORS.white
clearBtn.TextSize = 14
clearBtn.Font = Enum.Font.GothamBlack
clearBtn.Size = UDim2.new(0, 22, 0, 24)
clearBtn.Position = UDim2.new(1, -90, 0.5, -12)
clearBtn.BorderSizePixel = 0
clearBtn.ZIndex = 6
clearBtn.AutoButtonColor = false
clearBtn.Parent = row
corner(clearBtn, 7)
stroke(clearBtn, COLORS.strokeSoft, 1, 0.45)
speedKeybindButtons[keyId] = btn
btn.Activated:Connect(function()
listeningForSpeedKey = keyId
listeningForTPDownKey = false
keybindListenStartedAt = tick()
refreshAllSpeedKeybinds()
refreshTPDownKeybind()
end)
clearBtn.Activated:Connect(function()
listeningForSpeedKey = nil
listeningForTPDownKey = false
speedKeybinds[keyId] = nil
if speedKeybindButtons[keyId] then speedKeybindButtons[keyId].Text = "None" end
refreshAllSpeedKeybinds()
refreshTPDownKeybind()
saveDiceConfig()
end)
return row, btn
end
local normalModeValueLabel = nil
local laggerModeValueLabel = nil
local aimbotButtonLabel = nil
local aimbotSpeedLabel = nil
local laggerAimbotSpeedLabel = nil
local combatAimbotKeybindLabel = nil
function getAimbotModeDisplay()
if selectedAimbotMode == "Anti Bypass" or selectedAimbotMode == "Bypass" then
return "Anti Bypass"
end
return "Normal"
end
function refreshAimbotButtonLabel()
if aimbotButtonLabel then
aimbotButtonLabel.Text = getAimbotModeDisplay() .. " Aimbot"
end
end
function refreshAimbotModeLabels()
local modeName = getAimbotModeDisplay()
if aimbotSpeedLabel then
aimbotSpeedLabel.Text = modeName .. " Aimbot Speed"
end
if laggerAimbotSpeedLabel then
laggerAimbotSpeedLabel.Text = modeName .. " Lagger Aimbot Speed"
end
if combatAimbotKeybindLabel then
combatAimbotKeybindLabel.Text = modeName .. " Aimbot"
end
refreshAimbotButtonLabel()
end
refreshSpeedModeRows = function()
if normalModeValueLabel then
normalModeValueLabel.Text = (currentSpeedMode == "Carry") and "Carry" or "Normal"
end
if laggerModeValueLabel then
laggerModeValueLabel.Text = (currentSpeedMode == "Lagger Carry") and "Lagger Carry" or "Lagger"
end
end
function modeDisplayRow(parent, order, side)
local row = baseRow(parent, "Mode", order)
row.Size = UDim2.new(1, -4, 0, 42)
row.BackgroundTransparency = 0.42
local label = row:FindFirstChild("Label")
if label then
label.Text = "Mode"
label.TextSize = 11
label.Size = UDim2.new(0, 110, 1, 0)
label.Position = UDim2.new(0, 12, 0, 0)
label.TextColor3 = Color3.fromRGB(245, 245, 255)
end
local value = Instance.new("TextLabel")
value.Name = "ModeValue"
value.BackgroundTransparency = 1
value.Text = side == "Normal" and "Normal" or "Lagger"
value.TextColor3 = Color3.fromRGB(255, 255, 255)
value.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
value.TextStrokeTransparency = 0.25
value.TextSize = 12
value.Font = Enum.Font.GothamSemibold
value.TextXAlignment = Enum.TextXAlignment.Right
value.Position = UDim2.new(1, -132, 0, 0)
value.Size = UDim2.new(0, 120, 1, 0)
value.ZIndex = 6
value.Parent = row
local click = Instance.new("TextButton")
click.Name = "ModeClick"
click.BackgroundTransparency = 1
click.Text = ""
click.Size = UDim2.new(1, 0, 1, 0)
click.Position = UDim2.new(0, 0, 0, 0)
click.AutoButtonColor = false
click.ZIndex = 8
click.Parent = row
if side == "Normal" then
normalModeValueLabel = value
click.MouseButton1Click:Connect(function()
setSpeedMode(currentSpeedMode == "Normal" and "Carry" or "Normal")
end)
else
laggerModeValueLabel = value
click.MouseButton1Click:Connect(function()
setSpeedMode(currentSpeedMode == "Lagger" and "Lagger Carry" or "Lagger")
end)
end
refreshSpeedModeRows()
return row, value
end
function aimbotModeButtonRow(parent, order)
local row, setVisual = toggleRow(parent, tostring(selectedAimbotMode) .. " Aimbot", false, order)
aimbotButtonLabel = row and row:FindFirstChild("Label")
_G.DiceAimbotSetVisual = setVisual
refreshAimbotButtonLabel()
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
if _G.DiceToggleSelectedAimbot then _G.DiceToggleSelectedAimbot() end
end)
end
return row, setVisual
end
_G.DiceAimbotSelectorRow = function(parent, order)
local holder = Instance.new("Frame")
holder.Name = "Aimbot Mode"
holder.BackgroundColor3 = COLORS.row
holder.BackgroundTransparency = 0.28
holder.Size = UDim2.new(1, -4, 0, 42)
holder.BorderSizePixel = 0
holder.LayoutOrder = order
holder.ZIndex = 4
holder.ClipsDescendants = true
holder.Parent = parent
corner(holder, 9)
stroke(holder, COLORS.strokeSoft, 1.15, 0.38)
local slide = Instance.new("Frame")
slide.Name = "SelectedSlide"
slide.BackgroundColor3 = Color3.fromRGB(58, 58, 64)
slide.BackgroundTransparency = 0.08
slide.Size = UDim2.new(0.5, -3, 1, -8)
slide.Position = UDim2.new(0, 4, 0, 4)
slide.BorderSizePixel = 0
slide.ZIndex = 5
slide.Parent = holder
corner(slide, 9)
local slideStroke = Instance.new("UIStroke")
slideStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
slideStroke.Color = Color3.fromRGB(235, 235, 245)
slideStroke.Thickness = 1
slideStroke.Transparency = 0.08
slideStroke.Parent = slide
local slideGradient = Instance.new("UIGradient")
slideGradient.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 28)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(46, 46, 52)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 22)),
})
slideGradient.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.08),
NumberSequenceKeypoint.new(0.5, 0.02),
NumberSequenceKeypoint.new(1, 0.08),
})
slideGradient.Parent = slide
local normalText = Instance.new("TextLabel")
normalText.Name = "NormalText"
normalText.BackgroundTransparency = 1
normalText.Text = "NORMAL"
normalText.TextColor3 = COLORS.white
normalText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
normalText.TextStrokeTransparency = 0.2
normalText.TextSize = 11
normalText.Font = Enum.Font.GothamSemibold
normalText.TextXAlignment = Enum.TextXAlignment.Center
normalText.Size = UDim2.new(0.5, 0, 1, 0)
normalText.Position = UDim2.new(0, 0, 0, 0)
normalText.ZIndex = 8
normalText.Parent = holder
local bypassText = Instance.new("TextLabel")
bypassText.Name = "BypassText"
bypassText.BackgroundTransparency = 1
bypassText.Text = "ANTI BYPASS"
bypassText.TextColor3 = COLORS.white
bypassText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
bypassText.TextStrokeTransparency = 0.2
bypassText.TextSize = 10
bypassText.Font = Enum.Font.GothamSemibold
bypassText.TextXAlignment = Enum.TextXAlignment.Center
bypassText.Size = UDim2.new(0.5, 0, 1, 0)
bypassText.Position = UDim2.new(0.5, 0, 0, 0)
bypassText.ZIndex = 8
bypassText.Parent = holder
local normalClick = Instance.new("TextButton")
normalClick.Name = "NormalClick"
normalClick.BackgroundTransparency = 1
normalClick.Text = ""
normalClick.AutoButtonColor = false
normalClick.Size = UDim2.new(0.5, 0, 1, 0)
normalClick.Position = UDim2.new(0, 0, 0, 0)
normalClick.ZIndex = 10
normalClick.Parent = holder
local bypassClick = Instance.new("TextButton")
bypassClick.Name = "BypassClick"
bypassClick.BackgroundTransparency = 1
bypassClick.Text = ""
bypassClick.AutoButtonColor = false
bypassClick.Size = UDim2.new(0.5, 0, 1, 0)
bypassClick.Position = UDim2.new(0.5, 0, 0, 0)
bypassClick.ZIndex = 10
bypassClick.Parent = holder
local function setMode(mode)
if mode == "Bypass" then
mode = "Anti Bypass"
elseif mode ~= "Anti Bypass" then
mode = "Normal"
end
selectedAimbotMode = mode
refreshAimbotModeLabels()
if _G.DiceRefreshAimbotSpeedBoxes then _G.DiceRefreshAimbotSpeedBoxes() end
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
saveDiceConfig()
local onBypass = selectedAimbotMode == "Anti Bypass"
tween(slide, {
Position = onBypass and UDim2.new(0.5, -1, 0, 4) or UDim2.new(0, 4, 0, 4)
}, 0.18)
tween(normalText, {
TextTransparency = onBypass and 0.18 or 0,
TextStrokeTransparency = onBypass and 0.38 or 0.2
}, 0.14)
tween(bypassText, {
TextTransparency = onBypass and 0 or 0.18,
TextStrokeTransparency = onBypass and 0.2 or 0.38
}, 0.14)
end
normalClick.MouseButton1Click:Connect(function()
setMode("Normal")
end)
bypassClick.MouseButton1Click:Connect(function()
setMode("Anti Bypass")
end)
setMode(selectedAimbotMode)
return holder, setMode
end
function autoStealSelectorRow(parent, order)
local holder = Instance.new("Frame")
holder.Name = "Auto Steal Mode"
holder.BackgroundColor3 = COLORS.row
holder.BackgroundTransparency = 0.28
holder.Size = UDim2.new(1, -4, 0, 42)
holder.BorderSizePixel = 0
holder.LayoutOrder = order
holder.ZIndex = 4
holder.ClipsDescendants = true
holder.Parent = parent
corner(holder, 9)
stroke(holder, COLORS.strokeSoft, 1.15, 0.38)
local slide = Instance.new("Frame")
slide.Name = "SelectedSlide"
slide.BackgroundColor3 = Color3.fromRGB(58, 58, 64)
slide.BackgroundTransparency = 0.08
slide.Size = UDim2.new(0.5, -3, 1, -8)
slide.Position = UDim2.new(0, 4, 0, 4)
slide.BorderSizePixel = 0
slide.ZIndex = 5
slide.Parent = holder
corner(slide, 9)
local slideStroke = Instance.new("UIStroke")
slideStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
slideStroke.Color = Color3.fromRGB(235, 235, 245)
slideStroke.Thickness = 1
slideStroke.Transparency = 0.08
slideStroke.Parent = slide
local slideGradient = Instance.new("UIGradient")
slideGradient.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 24, 28)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(46, 46, 52)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 22)),
})
slideGradient.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0.08),
NumberSequenceKeypoint.new(0.5, 0.02),
NumberSequenceKeypoint.new(1, 0.08),
})
slideGradient.Parent = slide
local normalText = Instance.new("TextLabel")
normalText.Name = "NormalText"
normalText.BackgroundTransparency = 1
normalText.Text = "NORMAL"
normalText.TextColor3 = COLORS.white
normalText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
normalText.TextStrokeTransparency = 0.2
normalText.TextSize = 11
normalText.Font = Enum.Font.GothamSemibold
normalText.TextXAlignment = Enum.TextXAlignment.Center
normalText.Size = UDim2.new(0.5, 0, 1, 0)
normalText.Position = UDim2.new(0, 0, 0, 0)
normalText.ZIndex = 8
normalText.Parent = holder
local semiText = Instance.new("TextLabel")
semiText.Name = "SemiText"
semiText.BackgroundTransparency = 1
semiText.Text = "SEMI"
semiText.TextColor3 = COLORS.white
semiText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
semiText.TextStrokeTransparency = 0.2
semiText.TextSize = 11
semiText.Font = Enum.Font.GothamSemibold
semiText.TextXAlignment = Enum.TextXAlignment.Center
semiText.Size = UDim2.new(0.5, 0, 1, 0)
semiText.Position = UDim2.new(0.5, 0, 0, 0)
semiText.ZIndex = 8
semiText.Parent = holder
local normalClick = Instance.new("TextButton")
normalClick.Name = "NormalClick"
normalClick.BackgroundTransparency = 1
normalClick.Text = ""
normalClick.AutoButtonColor = false
normalClick.Size = UDim2.new(0.5, 0, 1, 0)
normalClick.Position = UDim2.new(0, 0, 0, 0)
normalClick.ZIndex = 10
normalClick.Parent = holder
local semiClick = Instance.new("TextButton")
semiClick.Name = "SemiClick"
semiClick.BackgroundTransparency = 1
semiClick.Text = ""
semiClick.AutoButtonColor = false
semiClick.Size = UDim2.new(0.5, 0, 1, 0)
semiClick.Position = UDim2.new(0.5, 0, 0, 0)
semiClick.ZIndex = 10
semiClick.Parent = holder
local function setMode(mode)
if mode ~= "Semi" then
mode = "Normal"
end
_G.DiceStealRadii = _G.DiceStealRadii or {Normal = 62, Semi = 9}
_G.DiceStealRadii[selectedStealMode] = tonumber(autoStealRadius) or _G.DiceStealRadii[selectedStealMode]
selectedStealMode = mode
autoStealRadius = _G.DiceStealRadii[selectedStealMode] or ((selectedStealMode == "Semi") and 9 or 62)
if autoStealRadiusBox then
autoStealRadiusBox.Text = tostring(autoStealRadius)
end
saveDiceConfig()
if _G.DiceNormalAutoStealSetRadius then _G.DiceNormalAutoStealSetRadius(_G.DiceStealRadii.Normal or 62) end
if _G.DiceSemiAutoStealSetRadius then _G.DiceSemiAutoStealSetRadius(_G.DiceStealRadii.Semi or 9) end
if _G.DiceAutoStealSync then _G.DiceAutoStealSync() end
local onSemi = selectedStealMode == "Semi"
tween(slide, {
Position = onSemi and UDim2.new(0.5, -1, 0, 4) or UDim2.new(0, 4, 0, 4)
}, 0.18)
tween(normalText, {
TextTransparency = onSemi and 0.18 or 0,
TextStrokeTransparency = onSemi and 0.38 or 0.2
}, 0.14)
tween(semiText, {
TextTransparency = onSemi and 0 or 0.18,
TextStrokeTransparency = onSemi and 0.2 or 0.38
}, 0.14)
end
normalClick.MouseButton1Click:Connect(function()
setMode("Normal")
end)
semiClick.MouseButton1Click:Connect(function()
setMode("Semi")
end)
setMode(selectedStealMode)
return holder, setMode
end
-- Spread the large one-time UI build over several frames so executing the
-- loadstring does not monopolize the client thread and visibly freeze play.
task.wait()
Movement = pages.MOVEMENT
section(Movement, "SPEED ENGINE", -4)
do
local _, setVisual = _G.DiceActionToggleRow(Movement, "Match WalkSpeed", diceMatchWalkSpeed == true, -25)
local row = Movement:FindFirstChild("Match WalkSpeed")
local btn = row and row:FindFirstChild("ToggleButton")
if btn then
btn.Activated:Connect(function()
diceMatchWalkSpeed = not (diceMatchWalkSpeed == true)
if setVisual then setVisual(diceMatchWalkSpeed == true) end
if not diceMatchWalkSpeed and DiceReleaseWalkSpeed then DiceReleaseWalkSpeed(nil) end
saveDiceConfig()
end)
end
end
section(Movement, "AUTO SPEED", -2)
_, setAutoCarrySpeedVisual = toggleRow(Movement, "Auto Carry Speed", autoCarrySpeedEnabled, -1)
do
local row = Movement:FindFirstChild("Auto Carry Speed")
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
autoCarrySpeedEnabled = not autoCarrySpeedEnabled
if autoCarrySpeedEnabled ~= true and _G.AutoCarrySpeed and _G.AutoCarrySpeed.Disable then
_G.AutoCarrySpeed.Disable()
end
if setAutoCarrySpeedVisual then setAutoCarrySpeedVisual(autoCarrySpeedEnabled == true) end
saveDiceConfig()
end)
end
end
section(Movement, "NORMAL SPEED", 1)
_, normalSpeedBox = textboxRow(Movement, "Normal Speed", tostring(NS), 2)
normalSpeedBox.FocusLost:Connect(function()
local v = tonumber(normalSpeedBox.Text)
if v and v > 0 and v <= 250 then
NS = v
end
normalSpeedBox.Text = tostring(NS)
end)
_, carrySpeedBox = textboxRow(Movement, "Carry Speed", tostring(CS), 3)
carrySpeedBox.FocusLost:Connect(function()
local v = tonumber(carrySpeedBox.Text)
if v and v > 0 and v <= 250 then
CS = v
end
carrySpeedBox.Text = tostring(CS)
end)
modeDisplayRow(Movement, 4, "Normal")
section(Movement, "LAGGER SPEED", 5)
_, laggerSpeedBox = textboxRow(Movement, "Lagger Speed", tostring(LAGGER_SPEED), 6)
laggerSpeedBox.FocusLost:Connect(function()
local v = tonumber(laggerSpeedBox.Text)
if v and v > 0 and v <= 250 then
LAGGER_SPEED = v
end
laggerSpeedBox.Text = tostring(LAGGER_SPEED)
end)
_, laggerCarrySpeedBox = textboxRow(Movement, "Lagger Carry Speed", tostring(LAGGER_CARRY_SPEED), 7)
laggerCarrySpeedBox.FocusLost:Connect(function()
local v = tonumber(laggerCarrySpeedBox.Text)
if v and v > 0 and v <= 250 then
LAGGER_CARRY_SPEED = v
end
laggerCarrySpeedBox.Text = tostring(LAGGER_CARRY_SPEED)
end)
modeDisplayRow(Movement, 8, "Lagger")
section(Movement, "TELEPORT", 9)
autoTPRow = nil
autoTPRow, setAutoTPVisual = toggleRow(Movement, "Auto TP Down", autoTPEnabled, 10)
do
local autoTPButton = autoTPRow and autoTPRow:FindFirstChild("ToggleButton")
if autoTPButton then
autoTPButton.MouseButton1Click:Connect(function()
if autoTPClickDebounce then return end
autoTPClickDebounce = true
local nextState = not autoTPEnabled
toggleAutoTP(nextState)
task.delay(0.15, function()
autoTPClickDebounce = false
if setAutoTPVisual then setAutoTPVisual(autoTPEnabled) end
end)
end)
end
if autoTPEnabled then
startAutoTP()
else
stopAutoTP()
end
end
_, autoTPHeightBox = textboxRow(Movement, "Auto TP Height", tostring(autoTPHeight), 11)
autoTPHeightBox.FocusLost:Connect(function()
local v = tonumber(autoTPHeightBox.Text)
if v and v >= -500 and v <= 500 then
autoTPHeight = v
end
autoTPHeightBox.Text = tostring(autoTPHeight)
saveDiceConfig()
end)
section(Movement, "JUMP", 15)
_, setInfJumpVisual = toggleRow(Movement, "Infinite Jump", infJumpEnabled, 16)
do
local row = Movement:FindFirstChild("Infinite Jump")
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
setInfJumpInternal(not infJumpEnabled)
if setInfJumpVisual then setInfJumpVisual(infJumpEnabled == true) end
saveDiceConfig()
end)
end
end
_, setAntiRagdollVisual = toggleRow(Movement, "Anti Ragdoll", antiRagdollEnabled, 17)
do
local row = Movement:FindFirstChild("Anti Ragdoll")
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
setAntiRagdoll(not antiRagdollEnabled)
if setAntiRagdollVisual then setAntiRagdollVisual(antiRagdollEnabled == true) end
saveDiceConfig()
end)
end
end
section(Movement, "BODY LOCK", 18)
do
_, setAntiBodylockVisual = toggleRow(Movement, "Anti Bodylock", _G.DiceAntiBodylockEnabled == true, 19)
local row = Movement:FindFirstChild("Anti Bodylock")
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
if _G.DiceAntiBodylockEnabled then
disableAntiBodylock()
else
enableAntiBodylock()
end
if setAntiBodylockVisual then setAntiBodylockVisual(_G.DiceAntiBodylockEnabled == true) end
saveDiceConfig()
end)
end
if _G.DiceAntiBodylockEnabled then
enableAntiBodylock()
end
end
animationPackRow(Movement, 20)
refreshSpeedModeRows()
task.wait()
Combat = pages.COMBAT
section(Combat, "AUTO STEAL", 1)
autoStealSelectorRow(Combat, 2)
_diceRow, setAutoStealVisual = toggleRow(Combat, "Auto Steal", autoStealEnabled, 3)
do
_diceBtn = _diceRow and _diceRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
autoStealEnabled = not autoStealEnabled
if setAutoStealVisual then
setAutoStealVisual(autoStealEnabled)
end
if _G.DiceAutoStealSync then _G.DiceAutoStealSync() end
saveDiceConfig()
end)
end
end
_, radiusBox = textboxRow(Combat, "Radius", tostring(autoStealRadius), 4)
autoStealRadiusBox = radiusBox
radiusBox.FocusLost:Connect(function()
local v = tonumber(radiusBox.Text)
if v and v > 0 and v <= 500 then
autoStealRadius = v
end
_G.DiceStealRadii = _G.DiceStealRadii or {Normal = 62, Semi = 9}
_G.DiceStealRadii[selectedStealMode] = autoStealRadius
radiusBox.Text = tostring(autoStealRadius)
if _G.DiceNormalAutoStealSetRadius then _G.DiceNormalAutoStealSetRadius(_G.DiceStealRadii.Normal or 62) end
if _G.DiceSemiAutoStealSetRadius then _G.DiceSemiAutoStealSetRadius(_G.DiceStealRadii.Semi or 9) end
if _G.DiceAutoStealSync then _G.DiceAutoStealSync() end
saveDiceConfig()
end)
section(Combat, "NORMAL/BYPASS AIMBOT", 5)
_G.DiceAimbotSelectorRow(Combat, 6)
_G.DiceAimbotSetVisual = nil
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
_G.DiceNormalAutoSwingRow, _G.DiceNormalAutoSwingSetVisual, _G.DiceNormalAutoSwingBtn = _G.DiceActionToggleRow(Combat, "Auto Swing", autoSwingEnabled, 7)
do
if _G.DiceNormalAutoSwingBtn then
_G.DiceNormalAutoSwingBtn.MouseButton1Click:Connect(function()
if _G.DiceAutoSwingClickBusy then return end
_G.DiceAutoSwingClickBusy = true
autoSwingEnabled = not autoSwingEnabled
if _G.DiceNormalAutoSwingSetVisual then _G.DiceNormalAutoSwingSetVisual(autoSwingEnabled) end
saveDiceConfig()
task.delay(0.12, function() _G.DiceAutoSwingClickBusy = false end)
end)
end
end
_G.DiceMirrorTPDownRow, _G.DiceMirrorTPDownSetVisual, _G.DiceMirrorTPDownBtn = _G.DiceActionToggleRow(Combat, "Mirror TP Down (Recommended)", mirrorTPDownEnabled, 7.1)
local mirrorTPDownLabel = _G.DiceMirrorTPDownRow and _G.DiceMirrorTPDownRow:FindFirstChild("Label")
if mirrorTPDownLabel then mirrorTPDownLabel.TextSize = 10 end
if _G.DiceMirrorTPDownBtn then
_G.DiceMirrorTPDownBtn.MouseButton1Click:Connect(function()
if _G.DiceMirrorTPDownClickBusy then return end
_G.DiceMirrorTPDownClickBusy = true
_G.DiceSetMirrorTPDown(not mirrorTPDownEnabled)
saveDiceConfig()
task.delay(0.12, function() _G.DiceMirrorTPDownClickBusy = false end)
end)
end
aimbotSpeedRow, aimbotSpeedBox = textboxRow(Combat, "Normal Aimbot Speed", tostring(AIMBOT_SPEED), 8)
_G.DiceAimbotSpeedBox = aimbotSpeedBox
aimbotSpeedLabel = aimbotSpeedRow and aimbotSpeedRow:FindFirstChild("Label")
refreshAimbotModeLabels()
aimbotSpeedBox.FocusLost:Connect(function()
local v = tonumber(aimbotSpeedBox.Text)
if v and v > 0 and v <= 250 then
_G.DiceSetSelectedAimbotSpeedValues(v, nil)
end
if _G.DiceRefreshAimbotSpeedBoxes then _G.DiceRefreshAimbotSpeedBoxes() else aimbotSpeedBox.Text = tostring(AIMBOT_SPEED) end
saveDiceConfig()
end)
laggerAimbotSpeedRow, laggerAimbotSpeedBox = textboxRow(Combat, "Normal Lagger Aimbot Speed", tostring(LAGGER_AIMBOT_SPEED), 9)
_G.DiceLaggerAimbotSpeedBox = laggerAimbotSpeedBox
laggerAimbotSpeedLabel = laggerAimbotSpeedRow and laggerAimbotSpeedRow:FindFirstChild("Label")
refreshAimbotModeLabels()
if _G.DiceRefreshAimbotSpeedBoxes then _G.DiceRefreshAimbotSpeedBoxes() end
laggerAimbotSpeedBox.FocusLost:Connect(function()
local v = tonumber(laggerAimbotSpeedBox.Text)
if v and v > 0 and v <= 250 then
_G.DiceSetSelectedAimbotSpeedValues(nil, v)
end
if _G.DiceRefreshAimbotSpeedBoxes then _G.DiceRefreshAimbotSpeedBoxes() else laggerAimbotSpeedBox.Text = tostring(LAGGER_AIMBOT_SPEED) end
saveDiceConfig()
end)
section(Combat, "ANTI DESYNC BAT", 10)
_G.DiceAntiDesyncAutoSwingRow, _G.DiceAntiDesyncAutoSwingSetVisual, _G.DiceAntiDesyncAutoSwingBtn = _G.DiceActionToggleRow(Combat, "Auto Swing", antiDesyncAutoSwingEnabled, 11)
do
if _G.DiceAntiDesyncAutoSwingBtn then
_G.DiceAntiDesyncAutoSwingBtn.MouseButton1Click:Connect(function()
if _G.DiceAntiDesyncAutoSwingClickBusy then return end
_G.DiceAntiDesyncAutoSwingClickBusy = true
antiDesyncAutoSwingEnabled = not antiDesyncAutoSwingEnabled
if _G.DiceAntiDesyncAutoSwingSetVisual then _G.DiceAntiDesyncAutoSwingSetVisual(antiDesyncAutoSwingEnabled) end
saveDiceConfig()
task.delay(0.12, function() _G.DiceAntiDesyncAutoSwingClickBusy = false end)
end)
end
end
_G.DiceAntiDesyncSetVisual = function(_) end
section(Combat, "COUNTERS", 13)
_diceRow, setBatCounterVisual = _G.DiceActionToggleRow(Combat, "Bat Counter", batCounterEnabled, 14)
do
_diceBtn = _diceRow and _diceRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
batCounterEnabled = not batCounterEnabled
if setBatCounterVisual then
setBatCounterVisual(batCounterEnabled)
end
if batCounterEnabled then
if _G.DiceStartBatCounter then _G.DiceStartBatCounter() end
else
if _G.DiceStopBatCounter then _G.DiceStopBatCounter() end
end
saveDiceConfig()
end)
end
end
_diceRow, setMedCounterVisual = _G.DiceActionToggleRow(Combat, "Med Counter", medCounterEnabled, 15)
do
_diceBtn = _diceRow and _diceRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
medCounterEnabled = not medCounterEnabled
if setMedCounterVisual then
setMedCounterVisual(medCounterEnabled)
end
if medCounterEnabled then
if _G.DiceStartMedCounter then _G.DiceStartMedCounter(LP.Character) end
else
if _G.DiceStopMedCounter then _G.DiceStopMedCounter() end
end
saveDiceConfig()
end)
end
end
_diceRow, _G.DiceSetNoPlayerCollisionVisual = _G.DiceActionToggleRow(Combat, "No Player Collision", _G.DiceNoPlayerCollisionEnabled, 16)
do
_diceBtn = _diceRow and _diceRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
_G.DiceNoPlayerCollisionEnabled = not _G.DiceNoPlayerCollisionEnabled
if _G.DiceSetNoPlayerCollisionVisual then _G.DiceSetNoPlayerCollisionVisual(_G.DiceNoPlayerCollisionEnabled) end
if _G.DiceNoPlayerCollisionEnabled then
if enableNoPlayerCollision then enableNoPlayerCollision() end
else
if disableNoPlayerCollision then disableNoPlayerCollision() end
end
saveDiceConfig()
end)
end
end
_diceRow, setSafeModeVisual = _G.DiceActionToggleRow(Combat, "Safe Mode", antiKickEnabled, 17)
do
_diceBtn = _diceRow and _diceRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
antiKickEnabled = not antiKickEnabled
if setSafeModeVisual then setSafeModeVisual(antiKickEnabled) end
if antiKickEnabled and _G.DiceSafeModeForceStop then _G.DiceSafeModeForceStop("SAFE MODE") end
saveDiceConfig()
end)
end
end
_diceRow, setAutoResetOnMedVisual = toggleRow(Combat, "Auto Reset On Med Fling", autoResetOnMedEnabled, 18)
do
_diceBtn = _diceRow and _diceRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
if _G.DiceSetAutoResetOnMed then
_G.DiceSetAutoResetOnMed(not autoResetOnMedEnabled)
else
autoResetOnMedEnabled = not autoResetOnMedEnabled
if setAutoResetOnMedVisual then setAutoResetOnMedVisual(autoResetOnMedEnabled) end
saveDiceConfig()
end
end)
end
end
task.wait()
Keybinds = pages.KEYBINDS
section(Keybinds, "MOVEMENT KEYBINDS", 1)
speedKeybindRow(Keybinds, "Speed Key", "SpeedToggle", 2)
speedKeybindRow(Keybinds, "Lagger Mode Key", "LaggerToggle", 3)
tpDownKeybindRow(Keybinds, 4)
speedKeybindRow(Keybinds, "Drop Brainrot", "DropBrainrot", 5)
section(Keybinds, "COMBAT KEYBINDS", 6)
aimbotKeybindRow = speedKeybindRow(Keybinds, "Normal Aimbot", "Aimbot", 7)
combatAimbotKeybindLabel = aimbotKeybindRow and aimbotKeybindRow:FindFirstChild("Label")
refreshAimbotModeLabels()
speedKeybindRow(Keybinds, "Anti Desync Bat", "AntiDesyncAimbot", 8)
speedKeybindRow(Keybinds, "Auto Left", "AutoLeft", 9)
speedKeybindRow(Keybinds, "Auto Right", "AutoRight", 10)
speedKeybindRow(Keybinds, "Instant Reset", "InstantReset", 12)
do
THEME_ACCENT = THEME_ACCENT or Color3.fromRGB(230, 230, 230)
THEME_ACCENT_DIM = THEME_ACCENT_DIM or Color3.fromRGB(145, 145, 145)
PlayerESP = PlayerESP or {enabled=false, playerData={}, conns={}, discordText="discord.gg/qgwhrFZXd"}
BoxedESPOptions = BoxedESPOptions or {box=false, tracer=false}
BoxedESPData = BoxedESPData or {}
BoxedESPConn = BoxedESPConn or nil
stretchRezConn = stretchRezConn or nil
antiLagDescConn = antiLagDescConn or nil
noCamCollisionConn = noCamCollisionConn or nil
noCamCollisionParts = noCamCollisionParts or {}
_diceNukeConns = _diceNukeConns or {}
_diceNukeOn = _diceNukeOn or false
_diceCustomFontOrig = _diceCustomFontOrig or {}
_diceCustomFontConn = _diceCustomFontConn or nil
_diceCustomFont = _diceCustomFont or nil
function startPlayerESP()
if PlayerESP.enabled then return end
PlayerESP.enabled = true
function cleanup(plr)
local d=PlayerESP.playerData[plr]; if not d then return end
pcall(function() if d.highlight then d.highlight:Destroy() end end)
pcall(function() if d.billboard then d.billboard:Destroy() end end)
if d.conns then for _,c in ipairs(d.conns) do pcall(function() c:Disconnect() end) end end
PlayerESP.playerData[plr]=nil
end
function setup(plr,char)
if not PlayerESP.enabled or plr==LP then return end
cleanup(plr)
local hrp=char and (char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart",5))
local head=char and (char:FindFirstChild("Head") or char:WaitForChild("Head",5))
if not hrp or not head then return end
local hl=Instance.new("Highlight")
hl.Name="DiceDuelsESP"; hl.Adornee=char; hl.FillColor=Color3.fromRGB(35,35,35); hl.FillTransparency=0.72
hl.OutlineColor=Color3.fromRGB(245,245,245); hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=char
local bb=Instance.new("BillboardGui")
bb.Name="DiceDuelsESPTag"; bb.Adornee=head; bb.Size=UDim2.new(0,124,0,34); bb.StudsOffset=Vector3.new(0,2.7,0); bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.Parent=head
local box=Instance.new("Frame",bb); box.Size=UDim2.new(1,0,1,0); box.BackgroundTransparency=1; box.BorderSizePixel=0
Instance.new("UICorner",box).CornerRadius=UDim.new(0,9)
local n=Instance.new("TextLabel",box); n.Size=UDim2.new(1,-10,0,17); n.Position=UDim2.new(0,5,0,2); n.BackgroundTransparency=1; n.TextColor3=Color3.fromRGB(255,255,255); n.Font=Enum.Font.GothamBlack; n.TextSize=15; n.TextStrokeTransparency=0.38
local sub=Instance.new("TextLabel",box); sub.Size=UDim2.new(1,-10,0,11); sub.Position=UDim2.new(0,5,0,19); sub.BackgroundTransparency=1; sub.TextColor3=Color3.fromRGB(180,180,180); sub.Font=Enum.Font.GothamBold; sub.TextSize=10; sub.TextStrokeTransparency=0.58
local conn=RunService.Heartbeat:Connect(function()
if not PlayerESP.enabled or not hrp.Parent then return end
local v=hrp.AssemblyLinearVelocity or hrp.Velocity
n.Text=string.format("%d speed", math.floor(Vector3.new(v.X,0,v.Z).Magnitude+0.5)); sub.Text=plr.Name
end)
PlayerESP.playerData[plr]={highlight=hl,billboard=bb,conns={conn}}
end
for _,plr in ipairs(Players:GetPlayers()) do if plr~=LP then if plr.Character then setup(plr,plr.Character) end; table.insert(PlayerESP.conns, plr.CharacterAdded:Connect(function(c) task.defer(setup,plr,c) end)) end end
table.insert(PlayerESP.conns, Players.PlayerAdded:Connect(function(plr) if plr~=LP then table.insert(PlayerESP.conns, plr.CharacterAdded:Connect(function(c) task.defer(setup,plr,c) end)) end end))
table.insert(PlayerESP.conns, Players.PlayerRemoving:Connect(cleanup))
end
function stopPlayerESP()
PlayerESP.enabled=false
for _,c in ipairs(PlayerESP.conns or {}) do pcall(function() c:Disconnect() end) end
PlayerESP.conns={}
for plr,d in pairs(PlayerESP.playerData or {}) do pcall(function() if d.highlight then d.highlight:Destroy() end end); pcall(function() if d.billboard then d.billboard:Destroy() end end) end
PlayerESP.playerData={}
end
function _diceEspColor()
return THEME_ACCENT or Color3.fromRGB(230,230,230)
end
function _safeDrawing(kind, props)
if not Drawing or not Drawing.new then return nil end
local ok, obj = pcall(function() return Drawing.new(kind) end)
if not ok or not obj then return nil end
for k,v in pairs(props or {}) do pcall(function() obj[k]=v end) end
return obj
end
function _cleanupBoxedESPPlayer(player)
local data = BoxedESPData[player]
if not data then return end
for _,obj in pairs(data) do
pcall(function()
obj.Visible = false
if obj.Remove then obj:Remove() end
end)
end
BoxedESPData[player] = nil
end
function _cleanupBoxedESP()
for player,_ in pairs(BoxedESPData) do _cleanupBoxedESPPlayer(player) end
end
function _updateBoxedESP()
local cam = workspace.CurrentCamera
if not cam then return end
local anyOn = BoxedESPOptions.box or BoxedESPOptions.tracer
if not anyOn then
_cleanupBoxedESP()
return
end
for _,player in ipairs(Players:GetPlayers()) do
if player == LP then continue end
local char = player.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local head = char and char:FindFirstChild("Head")
if not root or not head then
_cleanupBoxedESPPlayer(player)
continue
end
local rootPos,onScreen = cam:WorldToViewportPoint(root.Position)
local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0,0.55,0))
local data = BoxedESPData[player]
if not data then
data = {
box = _safeDrawing("Square",{Thickness=2,Filled=false,Transparency=1,Color=_diceEspColor()}),
tracer = _safeDrawing("Line",{Thickness=2,Transparency=1,Color=_diceEspColor()}),
}
BoxedESPData[player] = data
end
local color = _diceEspColor()
local height = math.abs(headPos.Y - rootPos.Y) * 2.15
if height < 20 or height ~= height then height = 65 end
local width = height / 2.15
local view = cam.ViewportSize
local centerX, centerY = view.X/2, view.Y/2
local targetX, targetY = rootPos.X, rootPos.Y + height/2
local targetVisible = onScreen and rootPos.Z > 0
if not targetVisible then
local dx = rootPos.X - centerX
local dy = rootPos.Y - centerY
if rootPos.Z <= 0 then
dx = -dx
dy = -dy
end
if math.abs(dx) < 1 and math.abs(dy) < 1 then
local rel = cam.CFrame:PointToObjectSpace(root.Position)
dx = rel.X
dy = -rel.Y
if rootPos.Z <= 0 then
dx = -dx
dy = -dy
end
end
local edgePad = 10
local scaleX = (dx ~= 0) and ((view.X/2 - edgePad) / math.abs(dx)) or math.huge
local scaleY = (dy ~= 0) and ((view.Y/2 - edgePad) / math.abs(dy)) or math.huge
local scale = math.min(scaleX, scaleY)
if scale == math.huge or scale ~= scale then scale = 1 end
targetX = math.clamp(centerX + dx * scale, edgePad, view.X - edgePad)
targetY = math.clamp(centerY + dy * scale, edgePad, view.Y - edgePad)
end
if data.box then
data.box.Color = color
data.box.Size = Vector2.new(width,height)
data.box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
data.box.Visible = BoxedESPOptions.box == true and targetVisible
end
if data.tracer then
data.tracer.Color = color
local localChar = LP.Character
local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
local localHead = localChar and localChar:FindFirstChild("Head")
local fromX, fromY
if localRoot then
local localScreen = cam:WorldToViewportPoint(localRoot.Position)
fromX = localScreen.X
fromY = localScreen.Y + 15
end
if not fromX or not fromY then
fromX = cam.ViewportSize.X/2
fromY = cam.ViewportSize.Y - 88
end
data.tracer.From = Vector2.new(fromX, fromY)
data.tracer.To = Vector2.new(targetX, targetY)
data.tracer.Visible = BoxedESPOptions.tracer == true
end
end
end
function refreshBoxedESP()
local anyOn = BoxedESPOptions.box or BoxedESPOptions.tracer
if anyOn and not BoxedESPConn then
BoxedESPConn = RunService.RenderStepped:Connect(_updateBoxedESP)
elseif (not anyOn) and BoxedESPConn then
BoxedESPConn:Disconnect()
BoxedESPConn = nil
_cleanupBoxedESP()
end
end
Players.PlayerRemoving:Connect(_cleanupBoxedESPPlayer)
SKY_PRESETS_LIST={"Off","Night","Aurora","Sunset","Galaxy","Tech","Sakura","Pink Night","Blood Moon","Emerald Dawn","Volcanic","Arctic","Midnight Ocean","Vaporwave","Toxic","Solar Eclipse","Hellscape","Heaven","Storm","Sunrise","Deep Space","Lavender Dream","Inferno","Mint Sky"}
SKY_PRESETS={Off={kind="off"},Night={clock=22,brightness=2,ambient={110,100,130},outAmb={120,110,140}},Aurora={clock=14,brightness=3,ambient={150,120,150},outAmb={160,130,150}},Sunset={clock=17.2,brightness=2.5,ambient={170,120,100},outAmb={180,130,110}},Galaxy={clock=0,brightness=1.5,ambient={70,60,100},outAmb={80,70,110}},Tech={clock=21,brightness=2.2,ambient={90,130,170},outAmb={100,140,180}},Sakura={clock=11,brightness=3.5,ambient={170,150,160},outAmb={180,160,170}},["Pink Night"]={clock=23,brightness=2.2,ambient={120,60,110},outAmb={140,70,120}},["Blood Moon"]={clock=22.5,brightness=1.6,ambient={130,40,40},outAmb={150,50,50}},["Emerald Dawn"]={clock=6.5,brightness=2.8,ambient={130,170,140},outAmb={140,180,150}},Volcanic={clock=19,brightness=2,ambient={180,80,40},outAmb={200,90,50}},Arctic={clock=9,brightness=3.2,ambient={200,220,235},outAmb={210,230,245}},["Midnight Ocean"]={clock=1.5,brightness=1.7,ambient={60,90,130},outAmb={70,100,140}},Vaporwave={clock=19.5,brightness=2.4,ambient={180,120,200},outAmb={190,130,210}},Toxic={clock=13,brightness=2.5,ambient={140,180,80},outAmb={150,190,90}},["Solar Eclipse"]={clock=12,brightness=0.9,ambient={50,40,60},outAmb={60,50,70}},Hellscape={clock=18,brightness=1.8,ambient={200,60,30},outAmb={220,70,40}},Heaven={clock=12,brightness=4,ambient={240,235,210},outAmb={250,245,220}},Storm={clock=15,brightness=1.4,ambient={90,90,110},outAmb={100,100,120}},Sunrise={clock=6.2,brightness=2.8,ambient={220,180,130},outAmb={230,190,140}},["Deep Space"]={clock=0,brightness=1,ambient={30,25,50},outAmb={40,35,60}},["Lavender Dream"]={clock=18.5,brightness=2.6,ambient={180,160,220},outAmb={190,170,230}},Inferno={clock=17.5,brightness=2.2,ambient={220,100,40},outAmb={235,110,50}},["Mint Sky"]={clock=10,brightness=3.2,ambient={180,230,210},outAmb={190,240,220}}}
function _vC3(t) return Color3.fromRGB(t[1],t[2],t[3]) end
function _v4mpClearSky()
for _,v in ipairs(Lighting:GetChildren()) do if v:GetAttribute("_DiceDuelsSky") then pcall(function() v:Destroy() end) end end
local terrain=workspace:FindFirstChildOfClass("Terrain"); if terrain then for _,v in ipairs(terrain:GetChildren()) do if v:GetAttribute("_DiceDuelsSky") then pcall(function() v:Destroy() end) end end end
end
function applyCustomSky(mode)
_v4mpClearSky(); local p=SKY_PRESETS[mode]
if not p or p.kind=="off" then Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=true; skyTheme="Off"; return end
Lighting.ClockTime=p.clock or 14; Lighting.Brightness=p.brightness or 2; if p.ambient then Lighting.Ambient=_vC3(p.ambient) end; if p.outAmb then Lighting.OutdoorAmbient=_vC3(p.outAmb) end
local atm=Instance.new("Atmosphere"); atm:SetAttribute("_DiceDuelsSky",true); atm.Density=0.35; atm.Color=Lighting.Ambient; atm.Decay=Lighting.OutdoorAmbient; atm.Parent=Lighting
local sky=Instance.new("Sky"); sky:SetAttribute("_DiceDuelsSky",true); sky.StarCount=(mode=="Galaxy" or mode=="Deep Space") and 10000 or 2000; sky.Parent=Lighting
skyTheme=mode
end
_G.DiceStretchFOV = _G.DiceStretchFOV or 120
function enableStretchRez()
fpsBoostEnabled=true
local cam=workspace.CurrentCamera
if not cam then return end
if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn=nil end
stretchRezConn=RunService.RenderStepped:Connect(function()
if not fpsBoostEnabled then if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn=nil end; return end
cam=workspace.CurrentCamera
if cam then
if not fovEnabled then pcall(function() cam.FieldOfView=_G.DiceStretchFOV end) end
end
end)
end
function disableStretchRez()
fpsBoostEnabled=false
if stretchRezConn then stretchRezConn:Disconnect(); stretchRezConn=nil end
if not fovEnabled and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView=70 end
end
function enableCustomFov() fovEnabled=true; workspace.CurrentCamera.FieldOfView=fovValue; if customFovConn then customFovConn:Disconnect() end; customFovConn=RunService.RenderStepped:Connect(function() if not fovEnabled then customFovConn:Disconnect(); customFovConn=nil; return end; workspace.CurrentCamera.FieldOfView=fovValue end) end
function disableCustomFov() fovEnabled=false; if customFovConn then customFovConn:Disconnect(); customFovConn=nil end; workspace.CurrentCamera.FieldOfView=fpsBoostEnabled and 107 or 70 end
function _applyAntiLagObj(obj)
pcall(function()
if obj:IsA("BasePart") then obj.Material=Enum.Material.Plastic; obj.Reflectance=0; obj.CastShadow=false
elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency=1
elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then obj.Enabled=false end
end)
end
function applyKTMOptimization()
pcall(function() Lighting.GlobalShadows=false; Lighting.FogEnd=1e10; Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0 end)
for _,obj in ipairs(workspace:GetDescendants()) do _applyAntiLagObj(obj) end
if antiLagDescConn then antiLagDescConn:Disconnect() end
antiLagDescConn=workspace.DescendantAdded:Connect(function(obj) if antiLagVisualEnabled or nukeOptimiserEnabled then _applyAntiLagObj(obj) end end)
end
function enableAntiLag() antiLagVisualEnabled=true; applyKTMOptimization() end
function disableAntiLag() antiLagVisualEnabled=false; if antiLagDescConn and not nukeOptimiserEnabled then antiLagDescConn:Disconnect(); antiLagDescConn=nil end end
function enableNukeOptimizer()
nukeOptimiserEnabled=true; _diceNukeOn=true; applyKTMOptimization(); applyCustomSky("Off")
for _,c in ipairs(_diceNukeConns) do pcall(function() c:Disconnect() end) end; _diceNukeConns={}
table.insert(_diceNukeConns, workspace.DescendantAdded:Connect(function(o) if nukeOptimiserEnabled then _applyAntiLagObj(o) end end))
task.spawn(function() while nukeOptimiserEnabled do pcall(function() setfpscap(240) end); task.wait(3) end end)
end
function disableNukeOptimizer() nukeOptimiserEnabled=false; _diceNukeOn=false; for _,c in ipairs(_diceNukeConns) do pcall(function() c:Disconnect() end) end; _diceNukeConns={} end
function enableNoCamCollision()
noCamCollisionEnabled=true; if noCamCollisionConn then noCamCollisionConn:Disconnect() end
noCamCollisionConn=RunService.RenderStepped:Connect(function()
if not noCamCollisionEnabled then return end
local cam=workspace.CurrentCamera; local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not cam or not hrp then return end
local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={char}; params.IgnoreWater=true
local res=workspace:Raycast(cam.CFrame.Position,(hrp.Position+Vector3.new(0,1.5,0))-cam.CFrame.Position,params)
local hit={}
if res and res.Instance and res.Instance:IsA("BasePart") then hit[res.Instance]=true; if noCamCollisionParts[res.Instance]==nil then noCamCollisionParts[res.Instance]=res.Instance.LocalTransparencyModifier end; res.Instance.LocalTransparencyModifier=1 end
for part,orig in pairs(noCamCollisionParts) do if not hit[part] then pcall(function() if part and part.Parent then part.LocalTransparencyModifier=orig end end); noCamCollisionParts[part]=nil end end
end)
end
function disableNoCamCollision() noCamCollisionEnabled=false; if noCamCollisionConn then noCamCollisionConn:Disconnect(); noCamCollisionConn=nil end; for p,orig in pairs(noCamCollisionParts) do pcall(function() if p and p.Parent then p.LocalTransparencyModifier=orig end end) end; noCamCollisionParts={} end
function enableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
function disableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
end
V = V or {}
V.skyTheme = skyTheme or V.skyTheme or "Off"
V.nukeOptEnabled = nukeOptimiserEnabled == true
V.customFontEnabled = false
V.potatoGraphicsEnabled = V.potatoGraphicsEnabled or false
function enableNoCamCollision()
noCamCollisionEnabled = true
if noCamCollisionConn then noCamCollisionConn:Disconnect() end
noCamCollisionConn = RunService.RenderStepped:Connect(function()
if not noCamCollisionEnabled then
if noCamCollisionConn then noCamCollisionConn:Disconnect();noCamCollisionConn=nil end
return
end
local cam = workspace.CurrentCamera
local char = LP.Character
if not cam or not char then return end
local hrp = char:FindFirstChild("HumanoidRootPart")
if not hrp then return end
local camPos = cam.CFrame.Position
local charPos = hrp.Position + Vector3.new(0,1.5,0)
local toChar = charPos - camPos
if toChar.Magnitude < 0.3 then return end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {char}
params.IgnoreWater = true
local hit = {}
local origin = camPos
local remaining = toChar
for _ = 1,12 do
if remaining.Magnitude < 0.2 then break end
local res = workspace:Raycast(origin,remaining,params)
if not res then break end
local part = res.Instance
if part and part:IsA("BasePart") and not part:IsDescendantOf(char) then
hit[part] = true
if noCamCollisionParts[part] == nil then noCamCollisionParts[part] = part.LocalTransparencyModifier end
part.LocalTransparencyModifier = 1
end
origin = res.Position + remaining.Unit * 0.02
remaining = charPos - origin
end
for part,orig in pairs(noCamCollisionParts) do
if not hit[part] then
pcall(function() if part and part.Parent then part.LocalTransparencyModifier = orig end end)
noCamCollisionParts[part] = nil
end
end
end)
end
function disableNoCamCollision()
noCamCollisionEnabled = false
if noCamCollisionConn then noCamCollisionConn:Disconnect();noCamCollisionConn=nil end
for part,orig in pairs(noCamCollisionParts) do
pcall(function() if part and part.Parent then part.LocalTransparencyModifier = orig end end)
end
noCamCollisionParts = {}
end
SKY_PRESETS_LIST = {"Off","Night","Aurora","Sunset","Galaxy","Tech","Sakura","Pink Night",
"Blood Moon","Emerald Dawn","Volcanic","Arctic","Midnight Ocean","Vaporwave","Toxic","Solar Eclipse",
"Hellscape","Heaven","Storm","Sunrise","Deep Space","Lavender Dream","Inferno","Mint Sky"}
SKY_PRESETS = {
["Off"] = {kind = "off"},
["Night"] = {clock=22,brightness=2,ambient={110,100,130},outAmb={120,110,140},sky={stars=4000,moon=18,sun=0,moonTex=true},atm={dens=0.45,color={120,60,180},decay={60,20,100},glare=0.5,haze=1.2}},
["Aurora"] = {clock=14,brightness=3,ambient={150,120,150},outAmb={160,130,150},atm={dens=0.55,color={255,80,200},decay={255,20,150},glare=2.5,haze=3},clouds={cover=0.7,dens=0.7,color={255,240,250}}},
["Sunset"] = {clock=17.2,brightness=2.5,ambient={170,120,100},outAmb={180,130,110},sky={stars=0,sun=25,moon=0},atm={dens=0.5,color={255,130,60},decay={255,80,30},glare=2,haze=2.5},clouds={cover=0.55,dens=0.55,color={255,200,140}}},
["Galaxy"] = {clock=0,brightness=1.5,ambient={70,60,100},outAmb={80,70,110},sky={stars=10000,moon=30,sun=0},atm={dens=0.15,color={40,20,80},decay={20,10,50},glare=0.3,haze=0.5}},
["Tech"] = {clock=21,brightness=2.2,ambient={90,130,170},outAmb={100,140,180},sky={stars=2000,moon=12},atm={dens=0.4,color={0,200,255},decay={150,0,255},glare=2,haze=2},clouds={cover=0.4,dens=0.6,color={100,200,255}}},
["Sakura"] = {clock=11,brightness=3.5,ambient={170,150,160},outAmb={180,160,170},sky={sun=8},atm={dens=0.3,color={255,200,220},decay={255,170,200},glare=1,haze=1.5},clouds={cover=0.6,dens=0.4,color={255,250,252}}},
["Pink Night"] = {clock=23,brightness=2.2,ambient={120,60,110},outAmb={140,70,120},sky={stars=5000,moon=22,sun=0,moonTex=true},atm={dens=0.5,color={255,80,180},decay={140,30,100},glare=0.7,haze=1.4},clouds={cover=0.3,dens=0.5,color={180,90,150}}},
["Blood Moon"] = {clock=22.5,brightness=1.6,ambient={130,40,40},outAmb={150,50,50},sky={stars=1500,moon=28,sun=0,moonTex=true},atm={dens=0.6,color={220,30,30},decay={120,10,10},glare=1.4,haze=2},clouds={cover=0.5,dens=0.7,color={120,30,30}}},
["Emerald Dawn"] = {clock=6.5,brightness=2.8,ambient={130,170,140},outAmb={140,180,150},sky={sun=18,moon=0,stars=0},atm={dens=0.4,color={80,200,140},decay={40,150,90},glare=1.8,haze=2.2},clouds={cover=0.5,dens=0.5,color={200,255,220}}},
["Volcanic"] = {clock=19,brightness=2,ambient={180,80,40},outAmb={200,90,50},sky={stars=200,sun=12,moon=0},atm={dens=0.75,color={255,60,0},decay={180,20,0},glare=3,haze=3.5},clouds={cover=0.8,dens=0.9,color={120,40,20}}},
["Arctic"] = {clock=9,brightness=3.2,ambient={200,220,235},outAmb={210,230,245},sky={sun=10,stars=0,moon=0},atm={dens=0.3,color={180,220,255},decay={140,200,240},glare=1.5,haze=1.8},clouds={cover=0.7,dens=0.6,color={250,253,255}}},
["Midnight Ocean"] = {clock=1.5,brightness=1.7,ambient={60,90,130},outAmb={70,100,140},sky={stars=6000,moon=24,sun=0,moonTex=true},atm={dens=0.5,color={20,60,140},decay={10,30,90},glare=0.6,haze=1.5}},
["Vaporwave"] = {clock=19.5,brightness=2.4,ambient={180,120,200},outAmb={190,130,210},sky={stars=1000,moon=14},atm={dens=0.45,color={255,100,220},decay={120,60,255},glare=2.2,haze=2.4},clouds={cover=0.5,dens=0.55,color={200,150,255}}},
["Toxic"] = {clock=13,brightness=2.5,ambient={140,180,80},outAmb={150,190,90},atm={dens=0.55,color={100,220,40},decay={60,150,20},glare=1.8,haze=2.6},clouds={cover=0.65,dens=0.7,color={180,255,120}}},
["Solar Eclipse"] = {clock=12,brightness=0.9,ambient={50,40,60},outAmb={60,50,70},sky={stars=3500,sun=22,moon=0},atm={dens=0.5,color={255,140,40},decay={30,20,40},glare=2.8,haze=1.8}},
["Hellscape"] = {clock=18,brightness=1.8,ambient={200,60,30},outAmb={220,70,40},sky={stars=100,sun=30,moon=0},atm={dens=0.85,color={255,30,0},decay={120,0,0},glare=3.5,haze=4},clouds={cover=0.95,dens=0.95,color={80,20,10}}},
["Heaven"] = {clock=12,brightness=4,ambient={240,235,210},outAmb={250,245,220},sky={sun=16,moon=0,stars=0},atm={dens=0.25,color={255,250,220},decay={255,240,200},glare=3,haze=1.5},clouds={cover=0.85,dens=0.5,color={255,255,255}}},
["Storm"] = {clock=15,brightness=1.4,ambient={90,90,110},outAmb={100,100,120},sky={stars=0,sun=6,moon=0},atm={dens=0.65,color={80,90,120},decay={40,50,80},glare=0.5,haze=3},clouds={cover=0.95,dens=0.95,color={60,65,80}}},
["Sunrise"] = {clock=6.2,brightness=2.8,ambient={220,180,130},outAmb={230,190,140},sky={sun=22,stars=0,moon=0},atm={dens=0.45,color={255,180,100},decay={255,140,80},glare=2.4,haze=2.2},clouds={cover=0.4,dens=0.4,color={255,220,180}}},
["Deep Space"] = {clock=0,brightness=1,ambient={30,25,50},outAmb={40,35,60},sky={stars=15000,moon=0,sun=0},atm={dens=0.08,color={15,5,40},decay={5,0,20},glare=0.2,haze=0.3}},
["Lavender Dream"] = {clock=18.5,brightness=2.6,ambient={180,160,220},outAmb={190,170,230},sky={stars=800,moon=16,sun=0},atm={dens=0.4,color={200,160,255},decay={160,120,220},glare=1.4,haze=1.8},clouds={cover=0.55,dens=0.5,color={220,200,255}}},
["Inferno"] = {clock=17.5,brightness=2.2,ambient={220,100,40},outAmb={235,110,50},sky={sun=26,moon=0,stars=0},atm={dens=0.6,color={255,90,20},decay={200,40,0},glare=3,haze=3.2},clouds={cover=0.7,dens=0.7,color={200,80,40}}},
["Mint Sky"] = {clock=10,brightness=3.2,ambient={180,230,210},outAmb={190,240,220},sky={sun=10},atm={dens=0.32,color={150,255,210},decay={100,220,180},glare=1.6,haze=1.6},clouds={cover=0.55,dens=0.45,color={240,255,250}}},
}
function _vC3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
function _v4mpClearSky()
for _, v in ipairs(Lighting:GetChildren()) do
if v:GetAttribute("_DiceDuelsSky") then pcall(function() v:Destroy() end) end
end
local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
for _, v in ipairs(terrain:GetChildren()) do
if v:GetAttribute("_DiceDuelsSky") then pcall(function() v:Destroy() end) end
end
end
end
function applyCustomSky(mode)
_v4mpClearSky()
local preset = SKY_PRESETS[mode]
if not preset or preset.kind == "off" then
Lighting.FogEnd = 100000; Lighting.FogStart = 0
Lighting.FogColor = Color3.fromRGB(192,192,192)
Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = true
V.skyTheme = "Off"
return
end
Lighting.FogEnd = 100000; Lighting.FogStart = 0
Lighting.FogColor = Color3.fromRGB(200,200,200)
Lighting.GlobalShadows = true
Lighting.ClockTime = preset.clock or 14
Lighting.Brightness = preset.brightness or 2
if preset.outAmb then Lighting.OutdoorAmbient = _vC3(preset.outAmb) end
if preset.ambient then Lighting.Ambient = _vC3(preset.ambient) end
if preset.sky then
local sky = Instance.new("Sky")
sky:SetAttribute("_DiceDuelsSky", true)
if preset.sky.stars then sky.StarCount = preset.sky.stars end
if preset.sky.moon then sky.MoonAngularSize = preset.sky.moon end
if preset.sky.sun then sky.SunAngularSize = preset.sky.sun end
if preset.sky.moonTex then sky.MoonTextureId = "rbxasset://sky/moon.jpg" end
sky.Parent = Lighting
end
if preset.atm then
local atm = Instance.new("Atmosphere")
atm:SetAttribute("_DiceDuelsSky", true)
atm.Density = preset.atm.dens or 0.3
atm.Color = _vC3(preset.atm.color)
atm.Decay = _vC3(preset.atm.decay)
atm.Glare = preset.atm.glare or 1
atm.Haze = preset.atm.haze or 1
atm.Parent = Lighting
end
local terrain = workspace:FindFirstChildOfClass("Terrain")
if preset.clouds and terrain then
local clouds = Instance.new("Clouds")
clouds:SetAttribute("_DiceDuelsSky", true)
clouds.Cover = preset.clouds.cover or 0.5
clouds.Density = preset.clouds.dens or 0.5
clouds.Color = _vC3(preset.clouds.color)
clouds.Parent = terrain
end
V.skyTheme = mode
end
function enableUltraMode()
V.ultraModeEnabled = true
applyKTMOptimization()
end
function disableUltraMode()
V.ultraModeEnabled = false
end
function enableRemoveAccessories()
V.removeAccessoriesEnabledSep = true
removeAccessoriesEnabled = true
removeAllAccessories()
if V.removeAccConn then V.removeAccConn:Disconnect() end
V.removeAccConn = Players.PlayerAdded:Connect(function(player)
player.CharacterAdded:Connect(function(char)
task.wait(0.5)
if V.removeAccessoriesEnabledSep or removeAccessoriesEnabled then
for _,obj in ipairs(char:GetDescendants()) do processAntiLagDescendant(obj) end
end
end)
end)
if antiLagDescConn then antiLagDescConn:Disconnect() end
antiLagDescConn = Workspace.DescendantAdded:Connect(function(obj)
if antiLagEnabled or V.ultraModeEnabled or removeAccessoriesEnabled or V.removeAccessoriesEnabledSep then
processAntiLagDescendant(obj)
end
end)
end
function disableRemoveAccessories()
V.removeAccessoriesEnabledSep = false
removeAccessoriesEnabled = false
if V.removeAccConn then V.removeAccConn:Disconnect(); V.removeAccConn = nil end
if not antiLagEnabled and not V.ultraModeEnabled and antiLagDescConn then antiLagDescConn:Disconnect(); antiLagDescConn = nil end
end
_nukeOptimizerOn = false
_nukeOptimizerConns = {}
_nukeOptimizerThreads = {}
function enableNukeOptimizer()
if _nukeOptimizerOn then return end
_nukeOptimizerOn = true
nukeOptimiserEnabled = true
V.nukeOptEnabled = true
local MaterialService = game:GetService("MaterialService")
local XMin, XMax = -560, -240
local ClothingClasses = {"Shirt","Pants","ShirtGraphic","Accessory","Hat","HairAccessory","FaceAccessory","NeckAccessory","ShoulderAccessory","FrontAccessory","BackAccessory","WaistAccessory"}
local BASE_NAMES = {"baseplate","spawnlocation","spawn location","spawn"}
function SafeDestroy(obj)
if obj and obj.Name == "Overhead" then return end
pcall(function() obj:Destroy() end)
end
function IsClothing(obj)
for _, className in ipairs(ClothingClasses) do
if obj:IsA(className) then return true end
end
return false
end
function IsCharacterPart(obj)
for _, plr in ipairs(Players:GetPlayers()) do
if plr.Character and obj:IsDescendantOf(plr.Character) then return true end
end
return false
end
function IsOutOfRange(obj)
if obj:IsA("BasePart") then
local x = obj.Position.X
return x < XMin or x > XMax
end
return false
end
function IsBase(obj)
if not obj:IsA("BasePart") then return false end
local nl = obj.Name:lower()
for _, n in ipairs(BASE_NAMES) do
if nl:find(n, 1, true) then return true end
end
return false
end
function IsInBase(obj)
local p = obj.Parent
while p and p ~= workspace do
if IsBase(p) then return true end
p = p.Parent
end
return false
end
function MakeTransparent(obj)
pcall(function()
if IsBase(obj) and not IsCharacterPart(obj) then
obj.Transparency = 1
obj.CastShadow = false
end
end)
end
function StripObject(obj)
pcall(function()
if obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("SpecialMesh") then
SafeDestroy(obj)
elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
pcall(function() obj.Enabled = false end)
SafeDestroy(obj)
elseif obj:IsA("SurfaceAppearance") then
SafeDestroy(obj)
elseif obj:IsA("BasePart") then
obj.CastShadow = false
obj.Material = Enum.Material.Plastic
obj.MaterialVariant = ""
obj.Reflectance = 0
end
end)
end
function CleanObject(obj)
pcall(function()
if obj:IsA("SurfaceAppearance") then
SafeDestroy(obj)
elseif obj:IsA("Decal") or obj:IsA("Texture") then
if not (obj.Name == "face" and obj.Parent and obj.Parent.Name == "Head") then SafeDestroy(obj) end
elseif obj:IsA("SpecialMesh") then
obj.TextureId = ""
elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
SafeDestroy(obj)
elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
SafeDestroy(obj)
elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Explosion") then
SafeDestroy(obj)
elseif obj:IsA("Animation") or obj:IsA("AnimationController") then
SafeDestroy(obj)
elseif obj:IsA("BasePart") then
obj.CastShadow = false
obj.Material = Enum.Material.Plastic
obj.MaterialVariant = ""
obj.Reflectance = 0
end
end)
end
function ApplyGreySky()
pcall(function()
for _, obj in ipairs(Lighting:GetChildren()) do
if obj:IsA("Sky") then obj:Destroy() end
end
local sky = Instance.new("Sky")
sky.SkyboxBk = ""; sky.SkyboxDn = ""; sky.SkyboxFt = ""
sky.SkyboxLf = ""; sky.SkyboxRt = ""; sky.SkyboxUp = ""
sky.CelestialBodiesShown = false
sky.Name = "_DiceDuelsNukeSky"
sky.Parent = Lighting
end)
end
function OptimizeLighting()
pcall(function()
Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.FogStart = 9e9
Lighting.EnvironmentDiffuseScale = 0
Lighting.EnvironmentSpecularScale = 0
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(60,60,60)
for _, v in ipairs(Lighting:GetChildren()) do
if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("Atmosphere") or v:IsA("Clouds") then
v:Destroy()
end
end
ApplyGreySky()
end)
end
function ApplyTerrain()
pcall(function()
local terrain = workspace:FindFirstChildOfClass("Terrain")
if terrain then
terrain.Decoration = false
terrain.WaterWaveSize = 0
terrain.WaterWaveSpeed = 0
terrain.WaterReflectance = 0
terrain.WaterTransparency = 1
end
end)
end
function OptimizeCharacter(char)
if not char then return end
task.spawn(function()
task.wait(0.3)
if not _nukeOptimizerOn then return end
for _, obj in ipairs(char:GetDescendants()) do
if IsClothing(obj) then SafeDestroy(obj) else CleanObject(obj) end
end
end)
end
pcall(function()
settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
end)
pcall(function() if setfpscap then setfpscap(999) end end)
table.insert(_nukeOptimizerThreads, task.spawn(function()
if not game:IsLoaded() then game.Loaded:Wait() end
OptimizeLighting()
ApplyTerrain()
for _, obj in ipairs(workspace:GetDescendants()) do
if not _nukeOptimizerOn then return end
if IsBase(obj) then
MakeTransparent(obj)
elseif IsClothing(obj) then
SafeDestroy(obj)
elseif IsInBase(obj) then
elseif IsCharacterPart(obj) then
elseif IsOutOfRange(obj) then
SafeDestroy(obj)
else
CleanObject(obj)
StripObject(obj)
end
end
for _, obj in ipairs(workspace:GetDescendants()) do MakeTransparent(obj) end
end))
table.insert(_nukeOptimizerConns, workspace.DescendantAdded:Connect(function(obj)
if not _nukeOptimizerOn then return end
task.defer(function()
if not _nukeOptimizerOn then return end
if IsBase(obj) then MakeTransparent(obj); return end
if IsClothing(obj) then
SafeDestroy(obj)
elseif IsInBase(obj) then
elseif IsCharacterPart(obj) then
elseif IsOutOfRange(obj) then
SafeDestroy(obj)
else
CleanObject(obj)
StripObject(obj)
end
end)
end))
table.insert(_nukeOptimizerConns, Lighting.DescendantAdded:Connect(function(obj)
if not _nukeOptimizerOn then return end
if obj:IsA("Atmosphere") or obj:IsA("Clouds") or obj:IsA("PostEffect") then SafeDestroy(obj) end
end))
table.insert(_nukeOptimizerConns, MaterialService.DescendantAdded:Connect(function(obj)
if not _nukeOptimizerOn then return end
SafeDestroy(obj)
end))
for _, plr in ipairs(Players:GetPlayers()) do
OptimizeCharacter(plr.Character)
table.insert(_nukeOptimizerConns, plr.CharacterAdded:Connect(OptimizeCharacter))
end
table.insert(_nukeOptimizerConns, Players.PlayerAdded:Connect(function(plr)
table.insert(_nukeOptimizerConns, plr.CharacterAdded:Connect(OptimizeCharacter))
end))
table.insert(_nukeOptimizerThreads, task.spawn(function()
while _nukeOptimizerOn do
task.wait(15)
pcall(function() collectgarbage("collect") end)
end
end))
end
function disableNukeOptimizer()
_nukeOptimizerOn = false
nukeOptimiserEnabled = false
V.nukeOptEnabled = false
for _, c in ipairs(_nukeOptimizerConns) do pcall(function() c:Disconnect() end) end
_nukeOptimizerConns = {}
_nukeOptimizerThreads = {}
end
function enableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
function disableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
__dice_src_enableNoCamCollision = enableNoCamCollision
function enableNoCamCollision()
__dice_src_enableNoCamCollision()
noCamCollisionEnabled = true
end
__dice_src_disableNoCamCollision = disableNoCamCollision
function disableNoCamCollision()
__dice_src_disableNoCamCollision()
noCamCollisionEnabled = false
end
function __DiceDuelsSetupVisualsUI()
local Utility = pages.VISUALS
local skyThemes = SKY_PRESETS_LIST or {"Off", "Night", "Aurora", "Sunset", "Galaxy", "Tech", "Sakura"}
local skyIndex = 1
for i, name in ipairs(skyThemes) do if name == skyTheme then skyIndex = i break end end
function skyThemeSelectorRow(parent, order)
local row = baseRow(parent, "Sky Theme", order)
row.Size = UDim2.new(1, -4, 0, 42)
row.ClipsDescendants = true
local label = row:FindFirstChild("Label")
if label then
label.Size = UDim2.new(0, 84, 1, 0)
label.TextSize = 11
end
local left = Instance.new("TextButton")
left.Name = "SkyLeft"
left.BackgroundColor3 = COLORS.accentSoft
left.BackgroundTransparency = 0.04
left.Text = "<"
left.TextColor3 = COLORS.white
left.TextSize = 12
left.Font = Enum.Font.GothamSemibold
left.Size = UDim2.new(0, 42, 0, 28)
left.Position = UDim2.new(1, -186, 0.5, -14)
left.BorderSizePixel = 0
left.ZIndex = 8
left.AutoButtonColor = false
left.Parent = row
corner(left, 8)
stroke(left, COLORS.strokeSoft, 1, 0.42)
local holder = Instance.new("Frame")
holder.Name = "SkyValueHolder"
holder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
holder.BackgroundTransparency = 0.28
holder.BorderSizePixel = 0
holder.Size = UDim2.new(0, 92, 0, 28)
holder.Position = UDim2.new(1, -139, 0.5, -14)
holder.ClipsDescendants = true
holder.ZIndex = 7
holder.Parent = row
corner(holder, 8)
stroke(holder, Color3.fromRGB(235, 235, 245), 1, 0.35)
local smoky = Instance.new("ImageLabel")
smoky.Name = "SmokyBackground"
smoky.BackgroundTransparency = 1
smoky.Image = "rbxassetid://99416158073201"
smoky.ImageTransparency = 1
smoky.ScaleType = Enum.ScaleType.Crop
smoky.Size = UDim2.new(1, 0, 1, 0)
smoky.Position = UDim2.new(0, 0, 0, 0)
smoky.Visible = false
smoky.ZIndex = 7
smoky.Parent = holder
corner(smoky, 8)
skyValueLabel = Instance.new("TextLabel")
skyValueLabel.Name = "SkyValue"
skyValueLabel.BackgroundTransparency = 1
skyValueLabel.Text = skyThemes[skyIndex]
skyValueLabel.TextColor3 = COLORS.white
skyValueLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
skyValueLabel.TextStrokeTransparency = 0.22
skyValueLabel.TextSize = 11
skyValueLabel.Font = Enum.Font.GothamSemibold
skyValueLabel.TextXAlignment = Enum.TextXAlignment.Center
skyValueLabel.Size = UDim2.new(1, 0, 1, 0)
skyValueLabel.ZIndex = 9
skyValueLabel.Parent = holder
local right = Instance.new("TextButton")
right.Name = "SkyRight"
right.BackgroundColor3 = COLORS.accentSoft
right.BackgroundTransparency = 0.04
right.Text = ">"
right.TextColor3 = COLORS.white
right.TextSize = 12
right.Font = Enum.Font.GothamSemibold
right.Size = UDim2.new(0, 42, 0, 28)
right.Position = UDim2.new(1, -42, 0.5, -14)
right.BorderSizePixel = 0
right.ZIndex = 8
right.AutoButtonColor = false
right.Parent = row
corner(right, 8)
stroke(right, COLORS.strokeSoft, 1, 0.42)
local function setSkyIndex(nextIndex)
if nextIndex < 1 then nextIndex = #skyThemes end
if nextIndex > #skyThemes then nextIndex = 1 end
skyIndex = nextIndex
skyTheme = skyThemes[skyIndex]
if applyCustomSky then applyCustomSky(skyTheme) end
if skyValueLabel then skyValueLabel.Text = skyTheme end
saveDiceConfig()
end
left.Activated:Connect(function()
setSkyIndex(skyIndex - 1)
end)
right.Activated:Connect(function()
setSkyIndex(skyIndex + 1)
end)
return row
end
section(Utility, "ESP", 1)
do
local espRow, setESPVisual = toggleRow(Utility, "ESP", espEnabled, 2)
setPlayerESPVisual = setESPVisual
_diceBtn = espRow and espRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
espEnabled = not espEnabled
if espEnabled then
if startPlayerESP then startPlayerESP() end
if BoxedESPOptions then BoxedESPOptions.box = true end
else
if stopPlayerESP then stopPlayerESP() end
if BoxedESPOptions then BoxedESPOptions.box = false end
end
if refreshBoxedESP then refreshBoxedESP() end
if setESPVisual then setESPVisual(espEnabled) end
saveDiceConfig()
end)
end
end
do
local tracerRow, setTracerVisual = toggleRow(Utility, "Show Tracker", showTracerEnabled, 3)
setTracerESPVisual = setTracerVisual
_diceBtn = tracerRow and tracerRow:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
showTracerEnabled = not showTracerEnabled
if BoxedESPOptions then
BoxedESPOptions.tracer = showTracerEnabled
BoxedESPOptions.box = espEnabled == true
end
if refreshBoxedESP then refreshBoxedESP() end
if setTracerVisual then setTracerVisual(showTracerEnabled) end
saveDiceConfig()
end)
end
end
do
local row, setVisual = _G.DiceActionToggleRow(Utility, "Ragdoll Countdown", ragdollCountdownEnabled, 4)
setRagdollCountdownVisual = setVisual
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
ragdollCountdownEnabled = not ragdollCountdownEnabled
if ragdollCountdownEnabled then hookRagdollCountdown(LP.Character) else stopRagdollCountdown() end
if setVisual then setVisual(ragdollCountdownEnabled) end
saveDiceConfig()
end)
end
end
section(Utility, "SKY THEME", 5)
skyThemeSelectorRow(Utility, 6)
section(Utility, "PERFORMANCE", 7)
do
local row, setVisual = toggleRow(Utility, "Stretch Rez", fpsBoostEnabled, 8)
setFPSBoostVisual = setVisual
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
fpsBoostEnabled = not fpsBoostEnabled
if fpsBoostEnabled then enableStretchRez() else disableStretchRez() end
if setVisual then setVisual(fpsBoostEnabled) end
saveDiceConfig()
end)
end
end
do
local row, setVisual = toggleRow(Utility, "Anti Lag", antiLagVisualEnabled, 9)
setAntiLagVisual = setVisual
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
if antiLagVisualEnabled then disableAntiLag() else enableAntiLag() end
if setVisual then setVisual(antiLagVisualEnabled) end
saveDiceConfig()
end)
end
end
do
local row, setVisual = _G.DiceActionToggleRow(Utility, "Nuke Optimiser", nukeOptimiserEnabled, 10)
setNukeOptimiserVisual = setVisual
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
if nukeOptimiserEnabled then disableNukeOptimizer() else enableNukeOptimizer() end
if setVisual then setVisual(nukeOptimiserEnabled) end
saveDiceConfig()
end)
end
end
section(Utility, "CAMERA", 11)
do
local row, setVisual = toggleRow(Utility, "FOV", fovEnabled, 12)
setFOVVisual = setVisual
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
if fovEnabled then disableCustomFov() else enableCustomFov() end
if setVisual then setVisual(fovEnabled) end
saveDiceConfig()
end)
end
end
do
local _, box = textboxRow(Utility, "FOV Value", tostring(fovValue), 13)
box.FocusLost:Connect(function()
local v = tonumber(box.Text)
if v and v >= 30 and v <= 120 then
fovValue = v
if fovEnabled and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = fovValue end
end
box.Text = tostring(fovValue)
saveDiceConfig()
end)
end
do
local row, setVisual = toggleRow(Utility, "No Cam Collision", noCamCollisionEnabled, 14)
setNoCamCollisionVisual = setVisual
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
if noCamCollisionEnabled then disableNoCamCollision() else enableNoCamCollision() end
if setVisual then setVisual(noCamCollisionEnabled) end
saveDiceConfig()
end)
end
end
section(Utility, "EFFECTS", 15)
do
local lightningEnabled = (_G.DiceLightningEnabled == true)
local row, setVisual = toggleRow(Utility, "Lightning Strikes", lightningEnabled, 16)
_diceBtn = row and row:FindFirstChild("ToggleButton")
if _diceBtn then
_diceBtn.Activated:Connect(function()
_G.DiceLightningEnabled = not (_G.DiceLightningEnabled == true)
if setVisual then setVisual(_G.DiceLightningEnabled == true) end
local lc = Main and Main:FindFirstChild("LightningFX")
if lc then lc.Visible = (_G.DiceLightningEnabled == true) end
saveDiceConfig()
end)
end
end
end
task.wait()
__DiceDuelsSetupVisualsUI()
Settings = pages.SETTINGS
diceGuiScaleValue = tonumber(savedConfig.diceGuiScaleValue) or diceGuiScaleValue
diceGuiScaleValue = math.clamp(tonumber(diceGuiScaleValue) or 0.52, 0.50, 1.50)
diceProgressBarScaleValue = tonumber(savedConfig.diceProgressBarScaleValue) or diceProgressBarScaleValue
diceMainScale = Main:FindFirstChild("DiceMainScale") or Instance.new("UIScale")
diceMainScale.Name = "DiceMainScale"
diceMainScale.Scale = diceGuiScaleValue
diceMainScale.Parent = Main
local function applyDiceProgressBarScale()
local sg = PlayerGui:FindFirstChild("StealBarGui")
local bar = sg and sg:FindFirstChild("StealBar")
if not bar then return end
local sc = bar:FindFirstChild("DiceProgressBarScale") or Instance.new("UIScale")
sc.Name = "DiceProgressBarScale"
sc.Scale = diceProgressBarScaleValue
sc.Parent = bar
end
_G.__DiceDuelsSetupSettingsUI = function()
section(Settings, "GUI SETTINGS", 1)
do
local row, setVisual = _G.DiceActionToggleRow(Settings, "Lock GUI", _G.DiceGuiLocked == true, 7)
setLockGuiVisual = setVisual
local btn = row and row:FindFirstChild("ToggleButton")
if btn then
btn.Activated:Connect(function()
_G.DiceGuiLocked = not (_G.DiceGuiLocked == true)
if setVisual then setVisual(_G.DiceGuiLocked == true) end
if DiceUpdateGuiLockVisual then DiceUpdateGuiLockVisual() end
saveDiceConfig()
end)
end
end
do
local row, setVisual = _G.DiceActionToggleRow(Settings, "Hide Mobile Buttons", _G.DiceHideMobileButtons == true, 8)
setHideMobileButtonsVisual = setVisual
local btn = row and row:FindFirstChild("ToggleButton")
if btn then
btn.Activated:Connect(function()
_G.DiceHideMobileButtons = not (_G.DiceHideMobileButtons == true)
if setVisual then setVisual(_G.DiceHideMobileButtons == true) end
if _G.DiceApplyMobileButtonsHidden then _G.DiceApplyMobileButtonsHidden() end
saveDiceConfig()
end)
end
end
function stepperRow(parent, labelText, defaultValue, order, callback, minValue, maxValue)
local row = Instance.new("Frame")
row.Name = labelText
row.BackgroundColor3 = COLORS.row
row.BackgroundTransparency = 0.22
row.Size = UDim2.new(1, -4, 0, 42)
row.BorderSizePixel = 0
row.LayoutOrder = order
row.ZIndex = 4
row.Parent = parent
corner(row, 10)
stroke(row, COLORS.strokeSoft, 1.15, 0.32)
local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Text = labelText
label.TextColor3 = Color3.fromRGB(245, 245, 255)
label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
label.TextStrokeTransparency = 0.25
label.TextSize = 11
label.Font = Enum.Font.GothamMedium
label.TextXAlignment = Enum.TextXAlignment.Left
label.Position = UDim2.new(0, 12, 0, 0)
label.Size = UDim2.new(1, -155, 1, 0)
label.ZIndex = 5
label.Parent = row
local value = defaultValue
local minus = Instance.new("TextButton")
minus.Name = "Minus"
minus.BackgroundColor3 = COLORS.accentSoft
minus.BackgroundTransparency = 0.1
minus.BorderSizePixel = 0
minus.Text = "-"
minus.TextColor3 = Color3.fromRGB(245, 245, 255)
minus.TextSize = 14
minus.Font = Enum.Font.GothamBlack
minus.AutoButtonColor = false
minus.Size = UDim2.new(0, 28, 0, 26)
minus.Position = UDim2.new(1, -118, 0.5, -13)
minus.ZIndex = 6
minus.Parent = row
corner(minus, 7)
stroke(minus, COLORS.strokeSoft, 1, 0.5)
local valueBox = Instance.new("TextLabel")
valueBox.Name = "Value"
valueBox.BackgroundColor3 = COLORS.accentSoft
valueBox.BackgroundTransparency = 0.05
valueBox.BorderSizePixel = 0
valueBox.Text = string.format("%.2f", value)
valueBox.TextColor3 = Color3.fromRGB(245, 245, 255)
valueBox.TextSize = 13
valueBox.Font = Enum.Font.GothamBlack
valueBox.TextXAlignment = Enum.TextXAlignment.Center
valueBox.Size = UDim2.new(0, 48, 0, 26)
valueBox.Position = UDim2.new(1, -84, 0.5, -13)
valueBox.ZIndex = 6
valueBox.Parent = row
corner(valueBox, 7)
stroke(valueBox, COLORS.strokeSoft, 1, 0.5)
local plus = Instance.new("TextButton")
plus.Name = "Plus"
plus.BackgroundColor3 = COLORS.accentSoft
plus.BackgroundTransparency = 0.1
plus.BorderSizePixel = 0
plus.Text = "+"
plus.TextColor3 = Color3.fromRGB(245, 245, 255)
plus.TextSize = 14
plus.Font = Enum.Font.GothamBlack
plus.AutoButtonColor = false
plus.Size = UDim2.new(0, 28, 0, 26)
plus.Position = UDim2.new(1, -30, 0.5, -13)
plus.ZIndex = 6
plus.Parent = row
corner(plus, 7)
stroke(plus, COLORS.strokeSoft, 1, 0.5)
local function setValue(nextValue)
value = math.clamp(math.floor((nextValue * 100) + 0.5) / 100, minValue or 0.50, maxValue or 1.50)
valueBox.Text = string.format("%.2f", value)
if callback then callback(value) end
end
minus.MouseButton1Click:Connect(function()
setValue(value - 0.05)
end)
plus.MouseButton1Click:Connect(function()
setValue(value + 0.05)
end)
return row
end
stepperRow(Settings, "GUI Scale", diceGuiScaleValue, 3, function(v)
diceGuiScaleValue = v
diceMainScale.Scale = v
saveDiceConfig()
end)
stepperRow(Settings, "Progress Bar Size", diceProgressBarScaleValue, 4, function(v)
diceProgressBarScaleValue = v
applyDiceProgressBarScale()
saveDiceConfig()
end)
speedKeybindRow(Settings, "Toggle UI", "ToggleUI", 5)
section(Settings, "MOBILE BUTTONS", 6)
stepperRow(Settings, "Mobile Buttons Size", tonumber(_G.DiceMobileButtonScale) or 0.75, 9, function(v)
_G.DiceMobileButtonScale = math.clamp(tonumber(v) or 0.35, 0.30, 1.35)
if _G.DiceApplyMobileButtonSize then _G.DiceApplyMobileButtonSize() end
saveDiceConfig()
end, 0.30, 1.35)
do
local row = baseRow(Settings, "Reset Mobile Buttons", 10)
local button = Instance.new("TextButton")
button.Name = "ResetMobileButtons"
button.BackgroundColor3 = Color3.fromRGB(232, 232, 238)
button.BackgroundTransparency = 0
button.BorderSizePixel = 0
button.Text = "RESET"
button.TextColor3 = Color3.fromRGB(0, 0, 0)
button.TextSize = 11
button.Font = Enum.Font.GothamBlack
button.AutoButtonColor = false
button.Size = UDim2.new(0, 78, 0, 26)
button.Position = UDim2.new(1, -88, 0.5, -13)
button.ZIndex = 7
button.Parent = row
corner(button, 8)
stroke(button, Color3.fromRGB(255, 255, 255), 1, 0.18)
button.Activated:Connect(function()
if _G.DiceResetMobileButtons then
_G.DiceResetMobileButtons()
else
_G.DiceMobileButtonScale = 0.75
_G.DiceHideMobileButtons = false
if _G.DiceApplyMobileButtonsHidden then _G.DiceApplyMobileButtonsHidden() end
if _G.DiceApplyMobileButtonSize then _G.DiceApplyMobileButtonSize() end
saveDiceConfig()
end
end)
end

section(Settings, "INTRO", 50)
do
local row, setVisual = toggleRow(Settings, "Intro", _introEnabled, 51)
setIntroVisual = setVisual
local btn = row and row:FindFirstChild("ToggleButton")
if btn then
btn.Activated:Connect(function()
_introEnabled = not _introEnabled
if not _introEnabled then stopIntroPlayback(); stopIntroPreview() end
if setIntroVisual then setIntroVisual(_introEnabled) end
saveDiceConfig()
end)
end
if setIntroVisual then setIntroVisual(_introEnabled) end
end
do
local row = Instance.new("Frame")
row.Name = "Intro Song"
row.BackgroundColor3 = COLORS.row
row.BackgroundTransparency = 0.22
row.Size = UDim2.new(1, -4, 0, 42)
row.BorderSizePixel = 0
row.LayoutOrder = 52
row.ZIndex = 4
row.Parent = Settings
corner(row, 10)
stroke(row, COLORS.strokeSoft, 1.15, 0.32)
local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Text = "Intro Song"
label.TextColor3 = Color3.fromRGB(245,245,255)
label.TextStrokeColor3 = Color3.fromRGB(0,0,0)
label.TextStrokeTransparency = 0.25
label.TextSize = 11
label.Font = Enum.Font.GothamMedium
label.TextXAlignment = Enum.TextXAlignment.Left
label.Position = UDim2.new(0, 12, 0, 0)
label.Size = UDim2.new(1, -145, 1, 0)
label.ZIndex = 5
label.Parent = row
local btn = Instance.new("TextButton")
btn.Name = "Intro Song Button"
btn.BackgroundColor3 = Color3.fromRGB(232,232,238)
btn.BackgroundTransparency = 0
btn.BorderSizePixel = 0
btn.Text = getIntroSongName()
btn.TextColor3 = Color3.fromRGB(0,0,0)
btn.TextSize = 12
btn.Font = Enum.Font.GothamBlack
btn.AutoButtonColor = false
btn.Size = UDim2.new(0, 118, 0, 28)
btn.Position = UDim2.new(1, -128, 0.5, -14)
btn.ZIndex = 6
btn.Parent = row
corner(btn, 8)
stroke(btn, Color3.fromRGB(255,255,255), 1, 0.15)
setIntroSongVisual = function()
if btn and btn.Parent then btn.Text = getIntroSongName(); btn.TextColor3 = Color3.fromRGB(0,0,0) end
end
btn.MouseButton1Click:Connect(function()
selectedIntroMusic = selectedIntroMusic + 1
if selectedIntroMusic > #INTRO_MUSIC_OPTIONS then selectedIntroMusic = 1 end
if setIntroSongVisual then setIntroSongVisual() end
previewIntroMusic(selectedIntroMusic)
saveDiceConfig()
end)
end

section(Settings, "SETTINGS", 999)
local resetHolder = Instance.new("Frame")
resetHolder.Name = "Reset All Settings Holder"
resetHolder.BackgroundTransparency = 1
resetHolder.BorderSizePixel = 0
resetHolder.Size = UDim2.new(1, -4, 0, 44)
resetHolder.LayoutOrder = 1000
resetHolder.ZIndex = 5
resetHolder.Parent = Settings
local resetBtn = Instance.new("TextButton")
resetBtn.Name = "Reset All Settings"
resetBtn.BackgroundColor3 = Color3.fromRGB(232, 232, 238)
resetBtn.BackgroundTransparency = 0
resetBtn.BorderSizePixel = 0
resetBtn.Text = "Reset All Settings"
resetBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
resetBtn.TextStrokeTransparency = 1
resetBtn.TextSize = 12
resetBtn.Font = Enum.Font.GothamBlack
resetBtn.AutoButtonColor = false
resetBtn.Size = UDim2.new(1, -16, 0, 42)
resetBtn.Position = UDim2.new(0, 8, 0, 1)
resetBtn.ZIndex = 6
resetBtn.Parent = resetHolder
corner(resetBtn, 10)
local resetStroke = Instance.new("UIStroke")
resetStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
resetStroke.Color = Color3.fromRGB(255, 255, 255)
resetStroke.Thickness = 1
resetStroke.Transparency = 0.12
resetStroke.Parent = resetBtn
local resetDefaultBg = Color3.fromRGB(232, 232, 238)
local resetHoverBg = Color3.fromRGB(245, 245, 250)
local resetConfirmBg = Color3.fromRGB(35, 35, 38)
local resetDoneBg = Color3.fromRGB(30, 30, 33)
local resetDefaultText = Color3.fromRGB(0, 0, 0)
local resetConfirmText = Color3.fromRGB(240, 240, 244)
local resetDoneText = Color3.fromRGB(210, 210, 215)
local confirmState = false
local confirmTimer = nil
function setResetDefaultTheme()
confirmState = false
resetBtn.Text = "RESET ALL SETTINGS"
resetBtn.TextColor3 = resetDefaultText
tween(resetBtn, {BackgroundColor3 = resetDefaultBg}, 0.18)
tween(resetStroke, {Color = Color3.fromRGB(255, 255, 255), Transparency = 0.12, Thickness = 1}, 0.18)
end
function setResetConfirmTheme()
resetBtn.Text = "CLICK AGAIN TO CONFIRM"
resetBtn.TextColor3 = resetConfirmText
tween(resetBtn, {BackgroundColor3 = resetConfirmBg}, 0.18)
tween(resetStroke, {Color = resetConfirmText, Transparency = 0.02, Thickness = 1.4}, 0.18)
end
function setResetDoneTheme()
resetBtn.Text = "DONE - REJOINING..."
resetBtn.TextColor3 = resetDoneText
tween(resetBtn, {BackgroundColor3 = resetDoneBg}, 0.18)
tween(resetStroke, {Color = resetDoneText, Transparency = 0.02, Thickness = 1.4}, 0.18)
end
resetBtn.Text = "RESET ALL SETTINGS"
resetBtn.MouseEnter:Connect(function()
if not confirmState then
tween(resetBtn, {BackgroundColor3 = resetHoverBg}, 0.12)
end
end)
resetBtn.MouseLeave:Connect(function()
if not confirmState then
tween(resetBtn, {BackgroundColor3 = resetDefaultBg}, 0.12)
end
end)
resetBtn.MouseButton1Click:Connect(function()
if not confirmState then
confirmState = true
setResetConfirmTheme()
if confirmTimer then task.cancel(confirmTimer) end
confirmTimer = task.delay(3, function()
setResetDefaultTheme()
end)
return
end
if confirmTimer then
task.cancel(confirmTimer)
confirmTimer = nil
end
resetBtn.Text = "RESETTING..."
pcall(function()
local files = {
CONFIG_FILE,
KEYBINDS_CONFIG_FILE,
"DiceDuels_MainGUI_Config.json",
"DiceDuelsConfig.json",
"DiceDuels_Settings.json",
"DiceDuels_Keybinds.json",
"DiceDuels_GUI.json",
}
for _, fname in ipairs(files) do
pcall(function()
if fname and isfile and isfile(fname) and delfile then
delfile(fname)
end
end)
end
end)
pcall(function()
diceGuiScaleValue = 0.52
diceProgressBarScaleValue = 0.83
NS = 59.5; CS = 28.8; LAGGER_SPEED = 29; LAGGER_CARRY_SPEED = 15
currentSpeedMode = "Normal"
autoCarrySpeedEnabled = false
autoTPHeight = 20
autoStealEnabled = false; selectedStealMode = "Normal"; autoStealRadius = 62
_G.DiceStealRadii = {Normal = 62, Semi = 9}
selectedAnimationPack = "OFF"; selectedAimbotMode = "Normal"
AIMBOT_SPEED = 58; LAGGER_AIMBOT_SPEED = 40
_G.DiceAntiBypassAimbotSpeed = 58; _G.DiceAntiBypassLaggerAimbotSpeed = 40; ANTI_DESYNC_AIMBOT_SPEED = 58
autoSwingEnabled = false; mirrorTPDownEnabled = false; antiDesyncAutoSwingEnabled = false
_G.DiceNormalAimbotOn = false; _G.DiceAntiBypassAimbotOn = false; _G.DiceAntiDesyncAimbotOn = false
antiRagdollEnabled = false; infJumpEnabled = false; autoTPEnabled = false
batCounterEnabled = false; medCounterEnabled = false; antiKickEnabled = false; autoResetOnMedEnabled = false
espEnabled = false; showTracerEnabled = false; ragdollCountdownEnabled = false
fpsBoostEnabled = false; antiLagVisualEnabled = false; nukeOptimiserEnabled = false
fovEnabled = false; fovValue = 70; noCamCollisionEnabled = false; _G.DiceNoPlayerCollisionEnabled = false
skyTheme = "Off"
selectedIntroMusic = 1; _introEnabled = true
if setIntroVisual then setIntroVisual(_introEnabled) end
if setIntroSongVisual then setIntroSongVisual() end
stopIntroPlayback(); stopIntroPreview()
autoLeftEnabled = false; autoRightEnabled = false
_G.DiceGuiLocked = false; _G.DiceHideMobileButtons = false; _G.DiceMobileButtonScale = 0.75
diceMainScale.Scale = diceGuiScaleValue
applyDiceProgressBarScale()
applyDefaultDiceKeybinds()
refreshAllSpeedKeybinds()
refreshTPDownKeybind()
if stopAutoTP then stopAutoTP() end
if stopAntiRagdoll then stopAntiRagdoll() end
if normalSpeedBox then normalSpeedBox.Text = tostring(NS) end
if carrySpeedBox then carrySpeedBox.Text = tostring(CS) end
if laggerSpeedBox then laggerSpeedBox.Text = tostring(LAGGER_SPEED) end
if laggerCarrySpeedBox then laggerCarrySpeedBox.Text = tostring(LAGGER_CARRY_SPEED) end
if autoTPHeightBox then autoTPHeightBox.Text = tostring(autoTPHeight) end
if radiusBox then radiusBox.Text = tostring(autoStealRadius) end
if _G.DiceRefreshAimbotSpeedBoxes then _G.DiceRefreshAimbotSpeedBoxes() end
if type(applyCustomSky) == "function" then applyCustomSky("Off") end
if skyValueLabel then skyValueLabel.Text = "Off" end
if _G.DiceResetMobileButtons then _G.DiceResetMobileButtons() end
if _G.DiceDuelsApplySavedGameplayStates then _G.DiceDuelsApplySavedGameplayStates() end
saveDiceConfig()
end)
task.wait(0.35)
setResetDoneTheme()
task.wait(0.6)
pcall(function()
local TeleportService = game:GetService("TeleportService")
TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
end)
end)
end
task.wait()
_G.__DiceDuelsSetupSettingsUI()
if DiceUpdateGuiLockVisual then DiceUpdateGuiLockVisual() end
if _G.DiceApplyMobileButtonsHidden then _G.DiceApplyMobileButtonsHidden() end
UserInputService.InputBegan:Connect(function(input, gameProcessed)
local isControllerInput = tostring(input.UserInputType):find("Gamepad") ~= nil
if gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and not listeningForSpeedKey and not listeningForTPDownKey then return end
if UserInputService:GetFocusedTextBox() then return end
if input.UserInputType ~= Enum.UserInputType.Keyboard and not isControllerInput then return end
if input.KeyCode == Enum.KeyCode.Unknown then return end
if speedKeybinds.ToggleUI and input.KeyCode == speedKeybinds.ToggleUI then
if Main.Visible then
Main.Visible = false
MiniFrame.Visible = true
else
Main.Visible = true
MiniFrame.Visible = false
Main.Size = FULL_MAIN_SIZE
end
saveDiceConfig()
return
end
if listeningForSpeedKey then
if tick() - (keybindListenStartedAt or 0) < 0.18 then return end
local targetKey = listeningForSpeedKey
if input.KeyCode == Enum.KeyCode.Escape then
listeningForSpeedKey = nil
refreshAllSpeedKeybinds()
return
end
if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
speedKeybinds[targetKey] = nil
else
for otherKeyId, boundKey in pairs(speedKeybinds) do
if otherKeyId ~= targetKey and boundKey == input.KeyCode then
speedKeybinds[otherKeyId] = nil
end
end
if tpDownKeybind == input.KeyCode then
tpDownKeybind = nil
refreshTPDownKeybind()
end
speedKeybinds[targetKey] = input.KeyCode
end
listeningForSpeedKey = nil
refreshAllSpeedKeybinds()
saveDiceConfig()
return
end
if listeningForTPDownKey then
if tick() - (keybindListenStartedAt or 0) < 0.18 then return end
if input.KeyCode == Enum.KeyCode.Escape then
listeningForTPDownKey = false
refreshTPDownKeybind()
return
end
if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
tpDownKeybind = nil
else
for keyId, boundKey in pairs(speedKeybinds) do
if boundKey == input.KeyCode then
speedKeybinds[keyId] = nil
end
end
tpDownKeybind = input.KeyCode
end
listeningForTPDownKey = false
refreshAllSpeedKeybinds()
refreshTPDownKeybind()
saveDiceConfig()
return
end
if speedKeybinds.SpeedToggle and input.KeyCode == speedKeybinds.SpeedToggle then
toggleCarryMode()
return
end
if speedKeybinds.LaggerToggle and input.KeyCode == speedKeybinds.LaggerToggle then
toggleLaggerMode()
return
end
if speedKeybinds.Aimbot and input.KeyCode == speedKeybinds.Aimbot then
if _G.DiceSafeModeIsLocked and _G.DiceSafeModeIsLocked() then
if _G.DiceSafeModeForceStop then _G.DiceSafeModeForceStop("SAFE MODE LOCK") end
return
end
if _G.DiceToggleSelectedAimbot then
_G.DiceToggleSelectedAimbot()
elseif selectedAimbotMode == "Anti Bypass" and _G.DiceStartAntiBypassAimbot and _G.DiceStopAntiBypassAimbot then
if _G.DiceAntiBypassAimbotOn then _G.DiceStopAntiBypassAimbot() else _G.DiceStartAntiBypassAimbot() end
elseif _G.DiceStartNormalAimbot and _G.DiceStopNormalAimbot then
if _G.DiceNormalAimbotOn then _G.DiceStopNormalAimbot() else _G.DiceStartNormalAimbot() end
end
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
return
end
if speedKeybinds.AntiDesyncAimbot and input.KeyCode == speedKeybinds.AntiDesyncAimbot then
if _G.DiceSafeModeIsLocked and _G.DiceSafeModeIsLocked() then
if _G.DiceSafeModeForceStop then _G.DiceSafeModeForceStop("SAFE MODE LOCK") end
return
end
if _G.DiceToggleAntiDesyncAimbot then
_G.DiceToggleAntiDesyncAimbot()
elseif _G.DiceStartAntiDesyncAimbot and _G.DiceStopAntiDesyncAimbot then
if _G.DiceAntiDesyncAimbotOn then _G.DiceStopAntiDesyncAimbot() else _G.DiceStartAntiDesyncAimbot() end
end
return
end
if speedKeybinds.DropBrainrot and input.KeyCode == speedKeybinds.DropBrainrot then
runDropBrainrot()
return
end
if speedKeybinds.AutoLeft and input.KeyCode == speedKeybinds.AutoLeft then
if _G.DiceSetAutoLeft then _G.DiceSetAutoLeft(not autoLeftEnabled) end
return
end
if speedKeybinds.AutoRight and input.KeyCode == speedKeybinds.AutoRight then
if _G.DiceSetAutoRight then _G.DiceSetAutoRight(not autoRightEnabled) end
return
end
if speedKeybinds.InstantReset and input.KeyCode == speedKeybinds.InstantReset then
if _G.DiceCursedInstaReset then _G.DiceCursedInstaReset() end
return
end
if tpDownKeybind and input.KeyCode == tpDownKeybind then
runTPFloor()
return
end
end)
setTab("MOVEMENT")
_G.__DiceDuelsSetupStealBar = function()
local RunService   = game:GetService("RunService")
local UIS = UserInputService
local TS = TweenService
local Stats        = game:GetService("Stats")
local existingStealBar = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("StealBarGui")
if existingStealBar then existingStealBar:Destroy() end
local THEME_ACCENT        = Color3.fromRGB(235, 235, 245)
local THEME_ACCENT_BRIGHT = Color3.fromRGB(255, 255, 255)
local THEME_ACCENT_DIM    = Color3.fromRGB(120, 120, 130)
local gui = Instance.new("ScreenGui")
gui.Name = "StealBarGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui
function drag(frame)
local dragging, dragStart, startPos = false, nil, nil
frame.InputBegan:Connect(function(input)
if _G.DiceGuiLocked == true then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragging = true
dragStart = input.Position
startPos = frame.Position
input.Changed:Connect(function()
if input.UserInputState == Enum.UserInputState.End then dragging = false end
end)
end
end)
UIS.InputChanged:Connect(function(input)
if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
local delta = input.Position - dragStart
frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
end)
end
-- ═══════════════════════════════════════════════════════════════
-- STEAL BAR
-- A rounded pill: percentage on the left, a track with a round knob
-- riding the fill, radius on the right, and a stat line underneath.
-- ═══════════════════════════════════════════════════════════════
local pbFrame = Instance.new("Frame", gui)
pbFrame.Name = "StealBar"
-- Tall enough for the stat line to sit inside the pill rather than
-- hanging off the bottom of it.
pbFrame.Size = UDim2.new(0, 372, 0, 60)
pbFrame.Position = UDim2.new(0.5, -186, 1, -100)
pbFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
pbFrame.BackgroundTransparency = 0.05
pbFrame.BorderSizePixel = 0
pbFrame.Active = true
pbFrame.ClipsDescendants = true
Instance.new("UICorner", pbFrame).CornerRadius = UDim.new(1, 0)
local pbSt = Instance.new("UIStroke", pbFrame)
pbSt.Color = THEME_ACCENT_BRIGHT
pbSt.Thickness = 1.6
pbSt.Transparency = 0.12
drag(pbFrame)
local pbScale = Instance.new("UIScale")
pbScale.Name = "DiceProgressBarScale"
pbScale.Scale = diceProgressBarScaleValue or 1
pbScale.Parent = pbFrame
local progressPct = Instance.new("TextLabel", pbFrame)
progressPct.Name = "Percent"
progressPct.Size = UDim2.new(0, 46, 0, 26)
progressPct.Position = UDim2.new(0, 14, 0, 8)
progressPct.BackgroundTransparency = 1
progressPct.Text = "0%"
progressPct.TextColor3 = Color3.fromRGB(255, 255, 255)
progressPct.Font = Enum.Font.GothamBold
progressPct.TextSize = 14
progressPct.TextXAlignment = Enum.TextXAlignment.Left
progressPct.ZIndex = 5
local progressRadLbl = Instance.new("TextLabel", pbFrame)
progressRadLbl.Name = "Radius"
progressRadLbl.Size = UDim2.new(0, 86, 0, 26)
progressRadLbl.Position = UDim2.new(1, -100, 0, 8)
progressRadLbl.BackgroundTransparency = 1
progressRadLbl.Text = "Radius: 0"
progressRadLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
progressRadLbl.Font = Enum.Font.GothamBold
progressRadLbl.TextSize = 14
progressRadLbl.TextXAlignment = Enum.TextXAlignment.Right
progressRadLbl.ZIndex = 5
local TRACK_WIDTH = 190
local TRACK_KNOB_R = 11
local fillRegion = Instance.new("Frame", pbFrame)
fillRegion.Name = "Track"
fillRegion.Size = UDim2.new(0, TRACK_WIDTH, 0, 18)
fillRegion.Position = UDim2.new(0, 66, 0, 12)
fillRegion.BackgroundColor3 = Color3.fromRGB(6, 6, 7)
fillRegion.BorderSizePixel = 0
fillRegion.ZIndex = 2
Instance.new("UICorner", fillRegion).CornerRadius = UDim.new(1, 0)
local fillRegStroke = Instance.new("UIStroke", fillRegion)
fillRegStroke.Color = THEME_ACCENT_BRIGHT
fillRegStroke.Thickness = 1.2
fillRegStroke.Transparency = 0.35
local progressFill = Instance.new("Frame", fillRegion)
progressFill.Name = "Fill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.Position = UDim2.new(0, 0, 0, 0)
progressFill.BackgroundColor3 = THEME_ACCENT_BRIGHT
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 3
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)
-- The knob rides the leading edge of the fill.
local progressKnob = Instance.new("Frame", fillRegion)
progressKnob.Name = "Knob"
progressKnob.AnchorPoint = Vector2.new(0.5, 0.5)
progressKnob.Size = UDim2.new(0, TRACK_KNOB_R * 2, 0, TRACK_KNOB_R * 2)
progressKnob.Position = UDim2.new(0, TRACK_KNOB_R, 0.5, 0)
progressKnob.BackgroundColor3 = Color3.fromRGB(238, 238, 242)
progressKnob.BorderSizePixel = 0
progressKnob.ZIndex = 6
Instance.new("UICorner", progressKnob).CornerRadius = UDim.new(1, 0)
local knobStroke = Instance.new("UIStroke", progressKnob)
knobStroke.Color = Color3.fromRGB(255, 255, 255)
knobStroke.Thickness = 1
knobStroke.Transparency = 0.4
local statLbl = Instance.new("TextLabel", pbFrame)
statLbl.Name = "Stats"
statLbl.Size = UDim2.new(1, -28, 0, 15)
statLbl.Position = UDim2.new(0, 14, 0, 38)
statLbl.BackgroundTransparency = 1
statLbl.Text = "FPS: 0  discord.gg/qgwhrFZXd  PING: 0ms"
statLbl.TextColor3 = Color3.fromRGB(232, 232, 238)
statLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
statLbl.TextStrokeTransparency = 0.55
statLbl.Font = Enum.Font.GothamSemibold
-- Scaled rather than fixed: the discord handle and a three-digit FPS
-- together are wider than the pill at a fixed size.
statLbl.TextScaled = true
statLbl.TextSize = 11
statLbl.TextXAlignment = Enum.TextXAlignment.Center
statLbl.ZIndex = 5
do
local limit = Instance.new("UITextSizeConstraint")
limit.MaxTextSize = 11
limit.MinTextSize = 7
limit.Parent = statLbl
end
local barState = "IDLE"
function setBarState(state)
barState = state
if state == "STEALING" then
TS:Create(fillRegion, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(16, 16, 18)}):Play()
TS:Create(progressPct, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
elseif state == "READY" then
TS:Create(fillRegion, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 23)}):Play()
TS:Create(progressPct, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
else
TS:Create(fillRegion, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(6, 6, 7)}):Play()
TS:Create(progressPct, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(168, 168, 174)}):Play()
end
end
task.spawn(function()
local lastFrame = tick()
local fpsSamples = {}
local fpsAvg = 60
RunService.RenderStepped:Connect(function()
local now = tick()
local dt = now - lastFrame
lastFrame = now
if dt > 0 then
table.insert(fpsSamples, 1 / dt)
if #fpsSamples > 30 then table.remove(fpsSamples, 1) end
local sum = 0
for _, v in ipairs(fpsSamples) do sum = sum + v end
fpsAvg = sum / #fpsSamples
end
end)
while pbFrame and pbFrame.Parent do
local ping = 0
pcall(function()
local stat = Stats.Network.ServerStatsItem["Data Ping"]
if stat then ping = tonumber(stat:GetValue()) or 0 end
end)
statLbl.Text = string.format("FPS: %d  discord.gg/qgwhrFZXd  PING: %dms", math.floor(fpsAvg + 0.5), math.floor(ping + 0.5))
progressRadLbl.Text = "Radius: " .. tostring(math.floor(tonumber(autoStealRadius) or 0))
task.wait(0.5)
end
end)
local StealBar = {}
function StealBar.SetProgress(p)
p = math.clamp(p, 0, 1)
progressFill.Size = UDim2.new(p, 0, 1, 0)
-- Inset by the knob's radius so it never hangs off either end. The
-- track's width is fixed, so this does not wait on layout to resolve.
progressKnob.Position = UDim2.new(0, TRACK_KNOB_R + p * (TRACK_WIDTH - TRACK_KNOB_R * 2), 0.5, 0)
progressPct.Text = math.floor(p * 100 + 0.5) .. "%"
end
function StealBar.Reset()
StealBar.SetProgress(0)
setBarState("IDLE")
end
function StealBar.SetState(state)
setBarState(state)
end
setBarState("IDLE")
_G.StealBar = StealBar
end
_G.__DiceDuelsSetupStealBar()
if _G.DiceAutoStealSync then task.defer(_G.DiceAutoStealSync) end
_G.__DiceDuelsSetupMinimizeToggle = function()
_G.__DiceDuelsMinimized = false
Close.MouseButton1Click:Connect(function()
_G.__DiceDuelsMinimized = not _G.__DiceDuelsMinimized
if _G.__DiceDuelsMinimized then
Main.Visible = false
MiniFrame.Visible = true
else
Main.Visible = true
MiniFrame.Visible = false
Main.Size = FULL_MAIN_SIZE
end
saveDiceConfig()
end)
end
_G.__DiceDuelsSetupMinimizeToggle()

_G.__DiceDuelsRunIntro = function()
local TS = TweenService
local introGuiParent = Gui and Gui.Parent or PlayerGui
local origSize = FULL_MAIN_SIZE or Main.Size
local wasMinimizedBeforeIntro = (_G.__DiceDuelsMinimized == true)
if not _introEnabled then
stopIntroPlayback()
stopIntroPreview()
Main.Size = origSize
if not wasMinimizedBeforeIntro then
Main.Visible = true
MiniFrame.Visible = false
else
Main.Visible = false
MiniFrame.Visible = true
end
return
end
playIntroMusic()
-- Keep the full menu/minimize tab hidden while the intro is playing.
Main.Visible = false
MiniFrame.Visible = false
Main.Size = UDim2.new(0, 0, 0, 0)
task.spawn(function()
local introGui = Instance.new("ScreenGui")
introGui.Name = "DiceDuelsIntro"
introGui.IgnoreGuiInset = true
introGui.DisplayOrder = 100
introGui.ResetOnSpawn = false
introGui.Parent = introGuiParent
local introActive = true
function finishIntro()
if not introActive then return end
introActive = false
stopIntroPlayback()
MiniFrame.Visible = false
Main.Visible = true
pcall(function()
TS:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = origSize}):Play()
end)
task.delay(0.75, function()
pcall(function() introGui:Destroy() end)
end)
end
local darkBg = Instance.new("Frame", introGui)
darkBg.Size = UDim2.new(1, 0, 1, 0)
darkBg.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
darkBg.BackgroundTransparency = 1
darkBg.BorderSizePixel = 0
darkBg.ZIndex = 1
local bgGrad = Instance.new("UIGradient", darkBg)
bgGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(42,42,46)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(18,18,20)), ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,12))})
bgGrad.Rotation = 90
local flashWash = Instance.new("Frame", introGui)
flashWash.Size = UDim2.new(1,0,1,0)
flashWash.BackgroundColor3 = Color3.fromRGB(255,255,255)
flashWash.BackgroundTransparency = 1
flashWash.BorderSizePixel = 0
flashWash.ZIndex = 2
local skipBtn = Instance.new("TextButton", introGui)
skipBtn.Name = "SkipIntro"
skipBtn.AnchorPoint = Vector2.new(1,0)
skipBtn.Position = UDim2.new(1,-22,0,22)
skipBtn.Size = UDim2.new(0,104,0,34)
skipBtn.BackgroundColor3 = Color3.fromRGB(235,235,240)
skipBtn.BackgroundTransparency = 0.08
skipBtn.BorderSizePixel = 0
skipBtn.Text = "SKIP INTRO"
skipBtn.TextColor3 = Color3.fromRGB(0,0,0)
skipBtn.TextSize = 11
skipBtn.Font = Enum.Font.GothamBlack
skipBtn.AutoButtonColor = false
skipBtn.ZIndex = 80
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0,10)
local skipStroke = Instance.new("UIStroke", skipBtn)
skipStroke.Color = Color3.fromRGB(255,255,255)
skipStroke.Thickness = 1
skipStroke.Transparency = 0.12
skipBtn.MouseButton1Click:Connect(finishIntro)
-- The intro tumbles dice rather than playing cards, built from the same
-- stack as the panel motif. Returns the die plus the layers to fade,
-- each paired with the transparency it settles at.
function makeIntroDie(parent, size, z, face)
local zi = z or 6
local radius = math.max(5, math.floor(size * 0.2))
local depth = math.max(2, math.floor(size * 0.085))
local die = Instance.new("Frame", parent)
die.Size = UDim2.new(0, size, 0, size)
die.AnchorPoint = Vector2.new(0.5, 0.5)
die.BackgroundTransparency = 1
die.BorderSizePixel = 0
die.ZIndex = zi
local parts = {}
local shade = Instance.new("Frame", die)
shade.Name = "Shadow"
shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shade.BackgroundTransparency = 1
shade.BorderSizePixel = 0
shade.Position = UDim2.new(0, depth + 2, 0, depth + 3)
shade.Size = UDim2.new(1, 2, 1, 2)
shade.ZIndex = zi
Instance.new("UICorner", shade).CornerRadius = UDim.new(0, radius + 2)
table.insert(parts, {obj = shade, t = 0.5})
local block = Instance.new("Frame", die)
block.Name = "Block"
block.BackgroundColor3 = Color3.fromRGB(126, 126, 132)
block.BackgroundTransparency = 1
block.BorderSizePixel = 0
block.Position = UDim2.new(0, depth, 0, depth)
block.Size = UDim2.new(1, 0, 1, 0)
block.ZIndex = zi + 1
Instance.new("UICorner", block).CornerRadius = UDim.new(0, radius)
local blockGrad = Instance.new("UIGradient", block)
blockGrad.Color = ColorSequence.new(Color3.fromRGB(170,170,176), Color3.fromRGB(88,88,94))
blockGrad.Rotation = 90
table.insert(parts, {obj = block, t = 0.06})
local faceFrame = Instance.new("Frame", die)
faceFrame.Name = "Face"
faceFrame.BackgroundColor3 = Color3.fromRGB(248, 248, 251)
faceFrame.BackgroundTransparency = 1
faceFrame.BorderSizePixel = 0
faceFrame.Size = UDim2.new(1, 0, 1, 0)
faceFrame.ZIndex = zi + 2
Instance.new("UICorner", faceFrame).CornerRadius = UDim.new(0, radius)
local grad = Instance.new("UIGradient", faceFrame)
grad.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(0.5, Color3.fromRGB(237,237,242)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(196,196,204)),
})
grad.Rotation = 118
table.insert(parts, {obj = faceFrame, t = 0.02})
local stroke = Instance.new("UIStroke", faceFrame)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Thickness = math.max(1, size * 0.05)
stroke.Transparency = 1
local rimGrad = Instance.new("UIGradient", stroke)
rimGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(112,112,120))
rimGrad.Rotation = 118
local sheen = Instance.new("Frame", faceFrame)
sheen.Name = "Sheen"
sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sheen.BackgroundTransparency = 1
sheen.BorderSizePixel = 0
sheen.Position = UDim2.new(0, math.floor(size * 0.1), 0, math.floor(size * 0.08))
sheen.Size = UDim2.new(1, -math.floor(size * 0.2), 0, math.max(2, math.floor(size * 0.34)))
sheen.ZIndex = zi + 3
Instance.new("UICorner", sheen).CornerRadius = UDim.new(0, math.max(2, math.floor(radius * 0.8)))
local sheenGrad = Instance.new("UIGradient", sheen)
sheenGrad.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 0),
NumberSequenceKeypoint.new(1, 1),
})
sheenGrad.Rotation = 90
table.insert(parts, {obj = sheen, t = 0.55})
local spots = DIE_PIPS[math.clamp(math.floor(tonumber(face) or 1), 1, 6)]
local pipSize = math.max(2, math.floor(size * 0.17))
for _, spot in ipairs(spots) do
local pip = Instance.new("Frame", faceFrame)
pip.AnchorPoint = Vector2.new(0.5, 0.5)
pip.Position = UDim2.new(spot[1], 0, spot[2], 0)
pip.Size = UDim2.new(0, pipSize, 0, pipSize)
pip.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
pip.BackgroundTransparency = 1
pip.BorderSizePixel = 0
pip.ZIndex = zi + 4
Instance.new("UICorner", pip).CornerRadius = UDim.new(1, 0)
local pipGrad = Instance.new("UIGradient", pip)
pipGrad.Color = ColorSequence.new(Color3.fromRGB(4,4,6), Color3.fromRGB(84,84,92))
pipGrad.Rotation = 118
local lip = Instance.new("UIStroke", pip)
lip.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
lip.Color = Color3.fromRGB(255, 255, 255)
lip.Thickness = math.max(0.5, size * 0.018)
lip.Transparency = 1
local lipGrad = Instance.new("UIGradient", lip)
lipGrad.Transparency = NumberSequence.new({
NumberSequenceKeypoint.new(0, 1),
NumberSequenceKeypoint.new(1, 0),
})
lipGrad.Rotation = 118
table.insert(parts, {obj = pip, t = 0})
end
return die, parts, stroke
end
-- Each layer settles at its own transparency, so fading a die in is a
-- walk over its parts rather than one tween on the frame.
local function fadeDieIn(parts, time)
for _, part in ipairs(parts) do
TS:Create(part.obj, TweenInfo.new(time), {BackgroundTransparency = part.t}):Play()
end
end
local function fadeDieOut(parts, time)
for _, part in ipairs(parts) do
TS:Create(part.obj, TweenInfo.new(time), {BackgroundTransparency = 1}):Play()
end
end
local cards = {}
for i = 1, 24 do
local size = math.random(34, 82)
local card, dieParts, stroke = makeIntroDie(introGui, size, 5 + i, math.random(1, 6))
local side = (i % 2 == 0) and -0.35 or 1.35
local targetSide = (i % 2 == 0) and 1.35 or -0.35
local y = math.random(4, 96) / 100
card.Position = UDim2.new(side, 0, y, 0)
card.Rotation = math.random(-40, 40)
cards[i] = {frame=card, parts=dieParts, stroke=stroke, startX=side, endX=targetSide, y=y, speed=0.09+math.random()*0.10, bob=math.random()*6.28, rot=math.random(-55,55), drift=math.random(-14,14)/100}
end
local introDie, introDiePips, introDieStroke = makeIntroDie(introGui, 130, 25, 5)
introDie.Position = UDim2.new(0.5,0,-0.35,0)
introDie.Rotation = -12
local t = 0
local driftConn = RunService.Heartbeat:Connect(function(dt)
if not introActive then return end
t = t + dt
for _, cd in ipairs(cards) do
local currentX = cd.frame.Position.X.Scale
local dir = cd.startX < cd.endX and 1 or -1
local newX = currentX + dir * cd.speed * dt
if (dir == 1 and newX > 1.40) or (dir == -1 and newX < -0.40) then newX = cd.startX end
local newY = math.clamp(cd.y + math.sin(t * 1.5 + cd.bob) * 0.035 + cd.drift, -0.08, 1.08)
cd.frame.Position = UDim2.new(newX, 0, newY, 0)
cd.frame.Rotation = cd.rot + math.sin(t * 2.5 + cd.bob) * 14
end
end)
local center = Instance.new("Frame", introGui)
center.AnchorPoint = Vector2.new(0.5,0.5); center.Position = UDim2.new(0.5,0,0.5,0); center.Size = UDim2.new(0,660,0,250)
center.BackgroundTransparency = 1; center.ZIndex = 40
local lineTop = Instance.new("Frame", center)
lineTop.AnchorPoint = Vector2.new(0.5,0); lineTop.Position = UDim2.new(0.5,0,0,58); lineTop.Size = UDim2.new(0,0,0,2)
lineTop.BackgroundColor3 = Color3.fromRGB(225,225,225); lineTop.BorderSizePixel = 0; lineTop.ZIndex = 41
local lineBot = Instance.new("Frame", center)
lineBot.AnchorPoint = Vector2.new(0.5,1); lineBot.Position = UDim2.new(0.5,0,1,-8); lineBot.Size = UDim2.new(0,0,0,2)
lineBot.BackgroundColor3 = Color3.fromRGB(225,225,225); lineBot.BorderSizePixel = 0; lineBot.ZIndex = 41
local titleShadow = Instance.new("TextLabel", center)
titleShadow.Size = UDim2.new(1,0,0,86); titleShadow.Position = UDim2.new(0,4,0,83); titleShadow.BackgroundTransparency = 1
titleShadow.Text = "DICE DUELS"; titleShadow.TextColor3 = Color3.fromRGB(0,0,0); titleShadow.Font = Enum.Font.GothamBlack; titleShadow.TextSize = 72
titleShadow.TextTransparency = 1; titleShadow.TextStrokeTransparency = 1; titleShadow.ZIndex = 42
local title = Instance.new("TextLabel", center)
title.Size = UDim2.new(1,0,0,86); title.Position = UDim2.new(0,0,0,78); title.BackgroundTransparency = 1
title.Text = "DICE DUELS"; title.TextColor3 = Color3.fromRGB(245,245,245); title.Font = Enum.Font.GothamBlack; title.TextSize = 72
title.TextTransparency = 1; title.TextStrokeTransparency = 1; title.TextStrokeColor3 = Color3.fromRGB(35,35,35); title.ZIndex = 43
local subtitle = Instance.new("TextLabel", center)
subtitle.Size = UDim2.new(1,0,0,26); subtitle.Position = UDim2.new(0,0,0,169); subtitle.BackgroundTransparency = 1
subtitle.Text = "Eugene"; subtitle.TextColor3 = Color3.fromRGB(200,200,200); subtitle.Font = Enum.Font.GothamMedium; subtitle.TextSize = 19; subtitle.TextTransparency = 1; subtitle.ZIndex = 43
TS:Create(darkBg, TweenInfo.new(0.65), {BackgroundTransparency = 0.22}):Play()
for _, cd in ipairs(cards) do
task.delay(math.random() * 0.9, function()
if not introActive then return end
fadeDieIn(cd.parts, 0.65)
if cd.stroke then TS:Create(cd.stroke, TweenInfo.new(0.65), {Transparency = 0.25}):Play() end
end)
end
task.wait(0.85); if not introActive then pcall(function() driftConn:Disconnect() end); return end
TS:Create(introDie, TweenInfo.new(1.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5,0,0.20,0), Rotation = 8}):Play()
if introDieStroke then TS:Create(introDieStroke, TweenInfo.new(0.55), {Transparency = 0.15}):Play() end
fadeDieIn(introDiePips, 0.55)
task.wait(1.05); if not introActive then pcall(function() driftConn:Disconnect() end); return end
TS:Create(lineTop, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,500,0,2)}):Play()
TS:Create(lineBot, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(0,500,0,2)}):Play()
task.wait(0.12)
TS:Create(titleShadow, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0.35, TextStrokeTransparency = 1}):Play()
TS:Create(title, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0, TextStrokeTransparency = 0.18}):Play()
task.wait(0.42)
TS:Create(subtitle, TweenInfo.new(0.42), {TextTransparency = 0}):Play()
for i = 1, 3 do
if not introActive then break end
TS:Create(title, TweenInfo.new(0.06), {TextColor3 = Color3.fromRGB(185,185,185)}):Play(); task.wait(0.06)
TS:Create(title, TweenInfo.new(0.06), {TextColor3 = Color3.fromRGB(245,245,245)}):Play(); task.wait(0.06)
end
task.wait(3.05)
if not introActive then pcall(function() driftConn:Disconnect() end); return end
TS:Create(center, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0)}):Play()
TS:Create(title, TweenInfo.new(0.36), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
TS:Create(titleShadow, TweenInfo.new(0.36), {TextTransparency = 1}):Play()
TS:Create(subtitle, TweenInfo.new(0.32), {TextTransparency = 1}):Play()
TS:Create(lineTop, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,2)}):Play()
TS:Create(lineBot, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,2)}):Play()
TS:Create(introDie, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {Position = UDim2.new(0.5,0,1.25,0), Rotation = 28}):Play()
fadeDieOut(introDiePips, 0.45)
if introDieStroke then TS:Create(introDieStroke, TweenInfo.new(0.45), {Transparency = 1}):Play() end
TS:Create(darkBg, TweenInfo.new(0.75), {BackgroundTransparency = 1}):Play()
for _, cd in ipairs(cards) do
fadeDieOut(cd.parts, 0.55)
if cd.stroke then TS:Create(cd.stroke, TweenInfo.new(0.55), {Transparency = 1}):Play() end
end
Main.Visible = true
MiniFrame.Visible = false
TS:Create(Main, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = origSize}):Play()
task.wait(0.9)
introActive = false
pcall(function() driftConn:Disconnect() end)
pcall(function() introGui:Destroy() end)
end)
end
_G.__DiceDuelsRunIntro()

_G.DiceDuelsForceSyncLoadedButtons = function()
pcall(function()
if setAutoTPVisual then setAutoTPVisual(autoTPEnabled) end
if autoTPEnabled then startAutoTP() else stopAutoTP() end
end)
pcall(function()
if setInfJumpVisual then setInfJumpVisual(infJumpEnabled) end
if setInfJumpInternal then setInfJumpInternal(infJumpEnabled) end
end)
pcall(function()
if setAntiRagdollVisual then setAntiRagdollVisual(antiRagdollEnabled) end
setAntiRagdoll(antiRagdollEnabled)
end)
pcall(function()
if _G.DiceSetAutoLeft then _G.DiceSetAutoLeft(autoLeftEnabled, true) end
if _G.DiceSetAutoRight then _G.DiceSetAutoRight(autoRightEnabled, true) end
end)
pcall(function()
if setAutoStealVisual then setAutoStealVisual(autoStealEnabled) end
if _G.DiceAutoStealSync then _G.DiceAutoStealSync() end
end)
pcall(function()
if _G.DiceNormalAutoSwingSetVisual then _G.DiceNormalAutoSwingSetVisual(autoSwingEnabled) end
if _G.DiceMirrorTPDownSetVisual then _G.DiceMirrorTPDownSetVisual(mirrorTPDownEnabled) end
if _G.DiceAntiDesyncAutoSwingSetVisual then _G.DiceAntiDesyncAutoSwingSetVisual(antiDesyncAutoSwingEnabled) end
if _G.DiceAntiDesyncSetVisual then _G.DiceAntiDesyncSetVisual(_G.DiceAntiDesyncAimbotOn == true) end
if _G.DiceAntiDesyncAimbotOn and _G.DiceStartAntiDesyncAimbot then
_G.DiceStartAntiDesyncAimbot()
elseif _G.DiceStopAntiDesyncAimbot then
_G.DiceStopAntiDesyncAimbot()
end
end)
pcall(function()
if selectedAimbotMode == "Anti Bypass" then
if _G.DiceNormalAimbotStop then _G.DiceNormalAimbotStop() end
if _G.DiceAntiBypassAimbotOn and _G.DiceAntiBypassStart then
_G.DiceAntiBypassStart()
elseif _G.DiceAntiBypassStop then
_G.DiceAntiBypassStop()
end
else
if _G.DiceAntiBypassStop then _G.DiceAntiBypassStop() end
if _G.DiceNormalAimbotOn and _G.DiceNormalAimbotStart then
_G.DiceNormalAimbotStart()
elseif _G.DiceNormalAimbotStop then
_G.DiceNormalAimbotStop()
end
end
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
end)
pcall(function()
if setBatCounterVisual then setBatCounterVisual(batCounterEnabled) end
if setMedCounterVisual then setMedCounterVisual(medCounterEnabled) end
if setSafeModeVisual then setSafeModeVisual(antiKickEnabled) end
if batCounterEnabled then
if _G.DiceStartBatCounter then _G.DiceStartBatCounter() end
else
if _G.DiceStopBatCounter then _G.DiceStopBatCounter() end
end
if medCounterEnabled then
if _G.DiceStartMedCounter then _G.DiceStartMedCounter(LP.Character) end
else
if _G.DiceStopMedCounter then _G.DiceStopMedCounter() end
end
if _G.DiceSetNoPlayerCollisionVisual then _G.DiceSetNoPlayerCollisionVisual(_G.DiceNoPlayerCollisionEnabled) end
if _G.DiceNoPlayerCollisionEnabled then
if enableNoPlayerCollision then enableNoPlayerCollision() end
else
if disableNoPlayerCollision then disableNoPlayerCollision() end
end
if _G.DiceSetAutoResetOnMed then
_G.DiceSetAutoResetOnMed(autoResetOnMedEnabled, true)
else
if setAutoResetOnMedVisual then setAutoResetOnMedVisual(autoResetOnMedEnabled) end
end
end)
pcall(function()
if setPlayerESPVisual then setPlayerESPVisual(espEnabled) end
if espEnabled then if startPlayerESP then startPlayerESP() end; if BoxedESPOptions then BoxedESPOptions.box = true end else if stopPlayerESP then stopPlayerESP() end; if BoxedESPOptions then BoxedESPOptions.box = false end end
if setTracerESPVisual then setTracerESPVisual(showTracerEnabled) end
if BoxedESPOptions then BoxedESPOptions.tracer = showTracerEnabled end
if refreshBoxedESP then refreshBoxedESP() end
if setRagdollCountdownVisual then setRagdollCountdownVisual(ragdollCountdownEnabled) end
if ragdollCountdownEnabled then hookRagdollCountdown(LP.Character) else stopRagdollCountdown() end
if setFPSBoostVisual then setFPSBoostVisual(fpsBoostEnabled) end
if fpsBoostEnabled then enableStretchRez() else disableStretchRez() end
if setAntiLagVisual then setAntiLagVisual(antiLagVisualEnabled) end
if antiLagVisualEnabled then enableAntiLag() else disableAntiLag() end
if setNukeOptimiserVisual then setNukeOptimiserVisual(nukeOptimiserEnabled) end
if nukeOptimiserEnabled then enableNukeOptimizer() else disableNukeOptimizer() end
if setFOVVisual then setFOVVisual(fovEnabled) end
if fovEnabled then enableCustomFov() else disableCustomFov() end
if setNoCamCollisionVisual then setNoCamCollisionVisual(noCamCollisionEnabled) end
if noCamCollisionEnabled then enableNoCamCollision() else disableNoCamCollision() end
if type(applyCustomSky) == "function" then
applyCustomSky((skyTheme and skyTheme ~= "") and skyTheme or "Off")
end
if skyValueLabel then skyValueLabel.Text = skyTheme or "Off" end
end)
pcall(saveDiceConfig)
end
task.defer(function()
task.wait(0.35)
if type(applyCustomSky) == "function" then
pcall(function() applyCustomSky((skyTheme and skyTheme ~= "") and skyTheme or "Off") end)
end
if skyValueLabel then skyValueLabel.Text = skyTheme or "Off" end
end)
task.defer(_G.DiceDuelsForceSyncLoadedButtons)
task.delay(1, function()
if _G.DiceDuelsForceSyncLoadedButtons then _G.DiceDuelsForceSyncLoadedButtons() end
end)
task.defer(function()
task.wait(0.2)
if _G.DiceSyncToggleVisuals then _G.DiceSyncToggleVisuals() end
end)
customFontVisualEnabled = false
if V then V.customFontEnabled = false end
function enableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
function disableCustomFont() customFontVisualEnabled=false; if V then V.customFontEnabled=false end end
_G.DiceDuelsApplySavedGameplayStates = function()
pcall(function()
if setAutoTPVisual then setAutoTPVisual(autoTPEnabled == true) end
if autoTPEnabled then startAutoTP() else stopAutoTP() end
end)
pcall(function()
if setInfJumpVisual then setInfJumpVisual(infJumpEnabled == true) end
if setInfJumpInternal then setInfJumpInternal(infJumpEnabled == true) end
end)
pcall(function()
if setAntiRagdollVisual then setAntiRagdollVisual(antiRagdollEnabled == true) end
if setAntiRagdoll then setAntiRagdoll(antiRagdollEnabled == true) end
end)
pcall(function()
if setAutoStealVisual then setAutoStealVisual(autoStealEnabled == true) end
if _G.DiceAutoStealSync then _G.DiceAutoStealSync() end
end)
pcall(function()
if setBatCounterVisual then setBatCounterVisual(batCounterEnabled == true) end
if batCounterEnabled and _G.DiceStartBatCounter then _G.DiceStartBatCounter() elseif _G.DiceStopBatCounter then _G.DiceStopBatCounter() end
end)
pcall(function()
if setMedCounterVisual then setMedCounterVisual(medCounterEnabled == true) end
if medCounterEnabled and _G.DiceStartMedCounter then _G.DiceStartMedCounter(LP.Character) elseif _G.DiceStopMedCounter then _G.DiceStopMedCounter() end
end)
pcall(function()
if _G.DiceSetNoPlayerCollisionVisual then _G.DiceSetNoPlayerCollisionVisual(_G.DiceNoPlayerCollisionEnabled == true) end
if _G.DiceNoPlayerCollisionEnabled then enableNoPlayerCollision() else disableNoPlayerCollision() end
end)
pcall(function()
if setSafeModeVisual then setSafeModeVisual(antiKickEnabled == true) end
end)
pcall(function()
if _G.DiceSetAutoResetOnMed then _G.DiceSetAutoResetOnMed(autoResetOnMedEnabled == true, true) end
end)
pcall(function()
if setPlayerESPVisual then setPlayerESPVisual(espEnabled == true) end
if espEnabled then if startPlayerESP then startPlayerESP() end else if stopPlayerESP then stopPlayerESP() end end
end)
pcall(function()
if setTracerESPVisual then setTracerESPVisual(showTracerEnabled == true) end
if BoxedESPOptions then BoxedESPOptions.tracer = showTracerEnabled == true end
if refreshBoxedESP then refreshBoxedESP() end
end)
pcall(function()
if setRagdollCountdownVisual then setRagdollCountdownVisual(ragdollCountdownEnabled == true) end
if ragdollCountdownEnabled then hookRagdollCountdown(LP.Character) else stopRagdollCountdown() end
end)
pcall(function()
if setFPSBoostVisual then setFPSBoostVisual(fpsBoostEnabled == true) end
if fpsBoostEnabled then enableStretchRez() else disableStretchRez() end
end)
pcall(function()
if setAntiLagVisual then setAntiLagVisual(antiLagVisualEnabled == true) end
if antiLagVisualEnabled then enableAntiLag() else disableAntiLag() end
end)
pcall(function()
if setNukeOptimiserVisual then setNukeOptimiserVisual(nukeOptimiserEnabled == true) end
if nukeOptimiserEnabled then enableNukeOptimizer() else disableNukeOptimizer() end
end)
pcall(function()
if setFOVVisual then setFOVVisual(fovEnabled == true) end
if fovEnabled then enableCustomFov() else disableCustomFov() end
end)
pcall(function()
if setNoCamCollisionVisual then setNoCamCollisionVisual(noCamCollisionEnabled == true) end
if noCamCollisionEnabled then enableNoCamCollision() else disableNoCamCollision() end
end)
pcall(function()
if type(applyCustomSky) == "function" then applyCustomSky((skyTheme and skyTheme ~= "") and skyTheme or "Off") end
if skyValueLabel then skyValueLabel.Text = skyTheme or "Off" end
end)
pcall(function()
if syncAnimationPackIndex then syncAnimationPackIndex() end
if refreshAnimationPackRow then refreshAnimationPackRow() end
if applySavedAnimationPackToCharacter then applySavedAnimationPackToCharacter(LP.Character) end
end)
end
task.defer(function()
task.wait(0.25)
if _G.DiceDuelsApplySavedGameplayStates then _G.DiceDuelsApplySavedGameplayStates() end
end)
task.delay(1.25, function()
if _G.DiceDuelsApplySavedGameplayStates then _G.DiceDuelsApplySavedGameplayStates() end
end)
task.delay(3, function()
if antiLagVisualEnabled and type(applyKTMOptimization) == "function" then pcall(applyKTMOptimization) end
if nukeOptimiserEnabled and type(applyKTMOptimization) == "function" then pcall(applyKTMOptimization) end
end)
_G.DiceAutoTPRestoreWanted = _G.DiceAutoTPRestoreWanted or false
_G.DiceAutoTPRestoreBlockedUntil = _G.DiceAutoTPRestoreBlockedUntil or 0
function diceAnyAimbotActive()
return (_G.DiceNormalAimbotOn == true) or (_G.DiceAntiBypassAimbotOn == true) or (_G.DiceAntiDesyncAimbotOn == true) or (_G.DiceAntiDesyncAimbotOn == true)
end
_G.DiceStopAutoTPForAction = function()
if autoTPEnabled then
_G.DiceAutoTPRestoreWanted = true
_G.DiceAutoTPRestoreBlockedUntil = tick() + 0.35
stopAutoTP()
if setAutoTPVisual then setAutoTPVisual(false) end
end
end
function diceTryRestoreAutoTP()
if not _G.DiceAutoTPRestoreWanted then return end
if tick() < (_G.DiceAutoTPRestoreBlockedUntil or 0) then return end
if diceAnyAimbotActive() then return end
if dropBrainrotActive then return end
_G.DiceAutoTPRestoreWanted = false
startAutoTP()
if setAutoTPVisual then setAutoTPVisual(true) end
saveDiceConfig()
end
RunService.Heartbeat:Connect(diceTryRestoreAutoTP)
_G._oldDiceStopNormalAimbot = _G.DiceStopNormalAimbot
_G.DiceStopNormalAimbot = function(...)
local r = {_G._oldDiceStopNormalAimbot(...)}
_G.DiceAutoTPRestoreBlockedUntil = tick() + 0.05
task.delay(0.08, diceTryRestoreAutoTP)
return unpack(r)
end
_G.DiceNormalAimbotStop = _G.DiceStopNormalAimbot
_G._oldDiceStopAntiBypassAimbot = _G.DiceStopAntiBypassAimbot
_G.DiceStopAntiBypassAimbot = function(...)
local r = {_G._oldDiceStopAntiBypassAimbot(...)}
_G.DiceAutoTPRestoreBlockedUntil = tick() + 0.05
task.delay(0.08, diceTryRestoreAutoTP)
return unpack(r)
end
_G.DiceAntiBypassStop = _G.DiceStopAntiBypassAimbot
_G._oldDiceStopAntiDesyncAimbot = _G.DiceStopAntiDesyncAimbot
_G.DiceStopAntiDesyncAimbot = function(...)
local r = {_G._oldDiceStopAntiDesyncAimbot(...)}
_G.DiceAutoTPRestoreBlockedUntil = tick() + 0.05
task.delay(0.08, diceTryRestoreAutoTP)
return unpack(r)
end
task.spawn(function()
local wasDropping = false
while task.wait(0.05) do
if dropBrainrotActive then
wasDropping = true
elseif wasDropping then
wasDropping = false
_G.DiceAutoTPRestoreBlockedUntil = tick() + 0.05
task.delay(0.08, diceTryRestoreAutoTP)
end
end
end)
function diceRepairKeybinds()
for keyId, defaultKey in pairs(DEFAULT_SPEED_KEYBINDS) do
if speedKeybinds[keyId] == Enum.KeyCode.Unknown then
speedKeybinds[keyId] = defaultKey
end
end
if tpDownKeybind == Enum.KeyCode.Unknown then tpDownKeybind = DEFAULT_TP_DOWN_KEYBIND end
if refreshAllSpeedKeybinds then refreshAllSpeedKeybinds() end
if refreshTPDownKeybind then refreshTPDownKeybind() end
end
_G._oldSaveDiceConfigStable = saveDiceConfig
saveDiceConfig = function()
diceRepairKeybinds()
return _G._oldSaveDiceConfigStable()
end
diceRepairKeybinds()
task.defer(function()
task.wait(0.2)
diceRepairKeybinds()
saveDiceConfig()
end)
task.defer(function()
task.wait(0.35)
local TS = game:GetService("TweenService")
local old = PlayerGui:FindFirstChild("DiceMobileButtons")
if old then old:Destroy() end
local mobileGui = Instance.new("ScreenGui")
mobileGui.Name = "DiceMobileButtons"
mobileGui.ResetOnSpawn = false
mobileGui.IgnoreGuiInset = true
mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
mobileGui.DisplayOrder = 1000
mobileGui.Parent = PlayerGui
_G.DiceMobileButtonRefs = {}
local mobileButtons = _G.DiceMobileButtonRefs
-- ═══════════════════════════════════════════════════════════════
-- MOBILE PANEL
-- One draggable grid rather than ten loose buttons. Each button is a
-- die: dark face with light pips when off, white face with dark pips
-- when on. Pips sit in the corners so the label never collides.
-- ═══════════════════════════════════════════════════════════════
local BTN_SIZE = 58
local BTN_GAP = 14
local PADDING = 6
local COLS = 3
local ROWS = 4
local PANEL_W = PADDING * 2 + COLS * BTN_SIZE + (COLS - 1) * BTN_GAP
local PANEL_H = PADDING * 2 + ROWS * BTN_SIZE + (ROWS - 1) * BTN_GAP
local PANEL_DEFAULT = UDim2.new(1, -(PANEL_W + 20), 0.5, -(PANEL_H / 2))
local FACE_OFF = Color3.fromRGB(18, 18, 21)
local FACE_ON = Color3.fromRGB(240, 240, 244)
local TEXT_OFF = Color3.fromRGB(232, 232, 238)
local TEXT_ON = Color3.fromRGB(14, 14, 16)
-- Corner-only pip spots keep the middle of the die clear for the label.
local MOBILE_PIPS = {
[2] = {{0.19, 0.18}, {0.81, 0.82}},
[4] = {{0.19, 0.18}, {0.81, 0.18}, {0.19, 0.82}, {0.81, 0.82}},
}
local MobilePanel = Instance.new("Frame")
MobilePanel.Name = "MobileButtonsPanel"
MobilePanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
MobilePanel.Position = tableToUDim2(_G.DiceMobileButtonPositions and _G.DiceMobileButtonPositions.panel, PANEL_DEFAULT)
MobilePanel.BackgroundTransparency = 1
MobilePanel.BorderSizePixel = 0
MobilePanel.Active = true
MobilePanel.ZIndex = 1000
MobilePanel.Parent = mobileGui
_G.DiceMobilePanel = MobilePanel
function _G.DiceApplyMobileButtonsHidden()
local g = PlayerGui:FindFirstChild("DiceMobileButtons")
if g then g.Enabled = not (_G.DiceHideMobileButtons == true) end
if setHideMobileButtonsVisual then pcall(setHideMobileButtonsVisual, _G.DiceHideMobileButtons == true) end
end
function _G.DiceApplyMobileButtonSize()
_G.DiceMobileButtonScale = math.clamp(tonumber(_G.DiceMobileButtonScale) or 0.75, 0.30, 1.35)
local sc = MobilePanel:FindFirstChild("MobileButtonScale") or Instance.new("UIScale")
sc.Name = "MobileButtonScale"
sc.Scale = _G.DiceMobileButtonScale
sc.Parent = MobilePanel
pcall(function()
local gui = PlayerGui:FindFirstChild("DiceDuelsAdaptReconstruct") or PlayerGui:FindFirstChild("AdaptHubPolished") or PlayerGui:FindFirstChild("CyberHub")
local root = gui or PlayerGui
for _, obj in ipairs(root:GetDescendants()) do
if obj.Name == "Mobile Buttons Size" then
local valueBox = obj:FindFirstChild("Value")
if valueBox and valueBox:IsA("TextLabel") then
valueBox.Text = string.format("%.2f", _G.DiceMobileButtonScale)
end
end
end
end)
end
-- The whole grid drags as one unit. Buttons feed the same drag state, so
-- you can grab the panel anywhere: a tap fires the button, a drag past
-- the threshold moves the panel and cancels the tap.
local panelDrag = {active = false, moved = false, start = nil, origin = nil}
local DRAG_DEADZONE = 6
local function beginPanelDrag(input)
if _G.DiceGuiLocked == true then return end
panelDrag.active = true
panelDrag.moved = false
panelDrag.start = input.Position
panelDrag.origin = MobilePanel.Position
end
local function endPanelDrag()
local moved = panelDrag.moved
panelDrag.active = false
panelDrag.moved = false
if moved then task.defer(saveDiceConfig) end
return moved
end
MobilePanel.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
beginPanelDrag(input)
end
end)
MobilePanel.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
endPanelDrag()
end
end)
UserInputService.InputChanged:Connect(function(input)
if not panelDrag.active or _G.DiceGuiLocked == true then return end
if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
local delta = input.Position - panelDrag.start
if not panelDrag.moved and (math.abs(delta.X) > DRAG_DEADZONE or math.abs(delta.Y) > DRAG_DEADZONE) then
panelDrag.moved = true
end
if panelDrag.moved then
MobilePanel.Position = UDim2.new(
panelDrag.origin.X.Scale, panelDrag.origin.X.Offset + delta.X,
panelDrag.origin.Y.Scale, panelDrag.origin.Y.Offset + delta.Y
)
end
end)
local function setActive(btn, state)
if not btn then return end
local pressed = btn:GetAttribute("DiceMobilePressed") == true
state = (state == true) or pressed
local visualState = state and "on" or "off"
if btn:GetAttribute("DiceMobileVisualState") == visualState then return end
btn:SetAttribute("DiceMobileVisualState", visualState)
TS:Create(btn, TweenInfo.new(0.15), {
BackgroundColor3 = state and FACE_ON or FACE_OFF,
TextColor3 = state and TEXT_ON or TEXT_OFF,
}):Play()
local st = btn:FindFirstChildOfClass("UIStroke")
if st then
TS:Create(st, TweenInfo.new(0.15), {
Color = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(78, 78, 84),
Transparency = state and 0.1 or 0.45,
}):Play()
end
local pipHolder = btn:FindFirstChild("Pips")
if pipHolder then
for _, pip in ipairs(pipHolder:GetChildren()) do
TS:Create(pip, TweenInfo.new(0.15), {
BackgroundColor3 = state and TEXT_ON or TEXT_OFF,
BackgroundTransparency = state and 0 or 0.35,
}):Play()
end
end
end
-- Momentary feedback for the buttons that fire an action rather than latch.
local function pulse(btn)
if not btn then return end
btn:SetAttribute("DiceMobilePressed", true)
setActive(btn, true)
task.delay(0.2, function()
if btn and btn.Parent then
btn:SetAttribute("DiceMobilePressed", false)
setActive(btn, false)
end
end)
end
local function makeButton(key, label, col, row, face, onPress)
local btn = Instance.new("TextButton")
btn.Name = "MB_" .. key
btn.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
btn.Position = UDim2.new(0, PADDING + col * (BTN_SIZE + BTN_GAP), 0, PADDING + row * (BTN_SIZE + BTN_GAP))
btn.BackgroundColor3 = FACE_OFF
btn.BorderSizePixel = 0
btn.Text = label
btn.TextColor3 = TEXT_OFF
btn.Font = Enum.Font.GothamBold
btn.TextSize = 10
btn.TextWrapped = true
btn.LineHeight = 1.15
btn.AutoButtonColor = false
btn.ZIndex = 1002
btn.Active = true
btn.Parent = MobilePanel
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
local st = Instance.new("UIStroke", btn)
st.Color = Color3.fromRGB(78, 78, 84)
st.Thickness = 1
st.Transparency = 0.45
st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local pipHolder = Instance.new("Frame", btn)
pipHolder.Name = "Pips"
pipHolder.Size = UDim2.new(1, 0, 1, 0)
pipHolder.BackgroundTransparency = 1
pipHolder.ZIndex = 1003
for _, spot in ipairs(MOBILE_PIPS[face] or MOBILE_PIPS[4]) do
local pip = Instance.new("Frame")
pip.AnchorPoint = Vector2.new(0.5, 0.5)
pip.Size = UDim2.new(0, 5, 0, 5)
pip.Position = UDim2.new(spot[1], 0, spot[2], 0)
pip.BackgroundColor3 = TEXT_OFF
pip.BackgroundTransparency = 0.35
pip.BorderSizePixel = 0
pip.ZIndex = 1003
pip.Parent = pipHolder
Instance.new("UICorner", pip).CornerRadius = UDim.new(1, 0)
end
btn.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
beginPanelDrag(input)
end
end)
btn.InputEnded:Connect(function(input)
if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
if not endPanelDrag() then pcall(onPress, btn) end
end)
mobileButtons[key] = {holder = MobilePanel, btn = btn, setActive = function(state) setActive(btn, state) end}
return btn
end
function _G.DiceResetMobileButtons()
_G.DiceMobileButtonScale = 0.75
_G.DiceHideMobileButtons = false
MobilePanel.Position = PANEL_DEFAULT
for _, entry in pairs(mobileButtons) do
local btn = entry and entry.btn
if btn then
btn:SetAttribute("DiceMobilePressed", false)
btn:SetAttribute("DiceMobileVisualState", nil)
end
end
if _G.DiceApplyMobileButtonSize then _G.DiceApplyMobileButtonSize() end
if _G.DiceApplyMobileButtonsHidden then _G.DiceApplyMobileButtonsHidden() end
if showActionNotification then pcall(function() showActionNotification("MOBILE BUTTONS RESET") end) end
saveDiceConfig()
end
-- Two pips mark the momentary actions, four the latching toggles.
makeButton("insta", "INSTA\nRESET", 0, 0, 2, function(btn)
if _G.DiceCursedInstaReset then _G.DiceCursedInstaReset() elseif cursedInstaReset then cursedInstaReset() end
pulse(btn)
end)
makeButton("drop", "DROP\nBR", 1, 0, 2, function(btn)
if runDropBrainrot then runDropBrainrot() elseif runDrop then runDrop() end
pulse(btn)
end)
makeButton("autoLeft", "AUTO\nLEFT", 2, 0, 4, function(btn)
if _G.DiceSetAutoLeft then _G.DiceSetAutoLeft(not autoLeftEnabled) end
task.delay(0.03, function()
if mobileButtons.autoLeft then mobileButtons.autoLeft.setActive(autoLeftEnabled == true) end
if mobileButtons.autoRight then mobileButtons.autoRight.setActive(autoRightEnabled == true) end
end)
end)
makeButton("antiDesync", "ANTI\nDESYNC", 0, 1, 4, function(btn)
if _G.DiceSafeModeIsLocked and _G.DiceSafeModeIsLocked() then
if _G.DiceSafeModeForceStop then _G.DiceSafeModeForceStop("SAFE MODE LOCK") end
return
end
if _G.DiceToggleAntiDesyncAimbot then
_G.DiceToggleAntiDesyncAimbot()
elseif _G.DiceStartAntiDesyncAimbot and _G.DiceStopAntiDesyncAimbot then
if _G.DiceAntiDesyncAimbotOn then _G.DiceStopAntiDesyncAimbot() else _G.DiceStartAntiDesyncAimbot() end
end
task.delay(0.03, function() setActive(btn, _G.DiceAntiDesyncAimbotOn == true) end)
end)
makeButton("aimbot", "BAT\nBOT", 1, 1, 4, function(btn)
if _G.DiceSafeModeIsLocked and _G.DiceSafeModeIsLocked() then
if _G.DiceSafeModeForceStop then _G.DiceSafeModeForceStop("SAFE MODE LOCK") end
return
end
if _G.DiceToggleSelectedAimbot then _G.DiceToggleSelectedAimbot() end
if _G.DiceRefreshAimbotVisual then _G.DiceRefreshAimbotVisual() end
task.delay(0.03, function()
setActive(btn, (_G.DiceNormalAimbotOn == true) or (_G.DiceAntiBypassAimbotOn == true))
end)
end)
makeButton("autoRight", "AUTO\nRIGHT", 2, 1, 4, function(btn)
if _G.DiceSetAutoRight then _G.DiceSetAutoRight(not autoRightEnabled) end
task.delay(0.03, function()
if mobileButtons.autoRight then mobileButtons.autoRight.setActive(autoRightEnabled == true) end
if mobileButtons.autoLeft then mobileButtons.autoLeft.setActive(autoLeftEnabled == true) end
end)
end)
makeButton("tp", "TP\nDOWN", 1, 2, 2, function(btn)
if runTPFloor then runTPFloor() end
pulse(btn)
end)
makeButton("carry", "CARRY\nSPEED", 2, 2, 4, function(btn)
if setSpeedMode then setSpeedMode(currentSpeedMode == "Carry" and "Normal" or "Carry") end
task.delay(0.03, function()
if mobileButtons.carry then mobileButtons.carry.setActive(currentSpeedMode == "Carry") end
if mobileButtons.laggerNormal then mobileButtons.laggerNormal.setActive(currentSpeedMode == "Lagger") end
if mobileButtons.laggerCarry then mobileButtons.laggerCarry.setActive(currentSpeedMode == "Lagger Carry") end
end)
end)
makeButton("laggerNormal", "LAGGER\nNORMAL", 1, 3, 4, function(btn)
if setSpeedMode then setSpeedMode(currentSpeedMode == "Lagger" and "Normal" or "Lagger") end
task.delay(0.03, function()
if mobileButtons.carry then mobileButtons.carry.setActive(currentSpeedMode == "Carry") end
if mobileButtons.laggerNormal then mobileButtons.laggerNormal.setActive(currentSpeedMode == "Lagger") end
if mobileButtons.laggerCarry then mobileButtons.laggerCarry.setActive(currentSpeedMode == "Lagger Carry") end
end)
end)
makeButton("laggerCarry", "LAGGER\nCARRY", 2, 3, 4, function(btn)
if setSpeedMode then setSpeedMode(currentSpeedMode == "Lagger Carry" and "Normal" or "Lagger Carry") end
task.delay(0.03, function()
if mobileButtons.carry then mobileButtons.carry.setActive(currentSpeedMode == "Carry") end
if mobileButtons.laggerNormal then mobileButtons.laggerNormal.setActive(currentSpeedMode == "Lagger") end
if mobileButtons.laggerCarry then mobileButtons.laggerCarry.setActive(currentSpeedMode == "Lagger Carry") end
end)
end)
_G.DiceApplyMobileButtonSize()
_G.DiceApplyMobileButtonsHidden()
RunService.Heartbeat:Connect(function()
if mobileButtons.autoLeft then mobileButtons.autoLeft.setActive(autoLeftEnabled == true) end
if mobileButtons.autoRight then mobileButtons.autoRight.setActive(autoRightEnabled == true) end
if mobileButtons.aimbot then mobileButtons.aimbot.setActive((_G.DiceNormalAimbotOn == true) or (_G.DiceAntiBypassAimbotOn == true)) end
if mobileButtons.antiDesync then mobileButtons.antiDesync.setActive(_G.DiceAntiDesyncAimbotOn == true) end
if mobileButtons.carry then mobileButtons.carry.setActive(currentSpeedMode == "Carry") end
if mobileButtons.laggerNormal then mobileButtons.laggerNormal.setActive(currentSpeedMode == "Lagger") end
if mobileButtons.laggerCarry then mobileButtons.laggerCarry.setActive(currentSpeedMode == "Lagger Carry") end
end)
end)
