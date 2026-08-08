--[[
	SpiderUI · example build
	------------------------
	A working menu laid out like a typical duels/steal hub, wired to nothing so
	you can drop your own logic into each Callback. Run SpiderUI.lua first (or
	loadstring it) and this file becomes the whole interface.
--]]

-- Point SOURCE at wherever you host SpiderUI.lua, or assign _G.SpiderUI first.
local SOURCE = "https://raw.githubusercontent.com/USER/REPO/main/SpiderUI.lua"
local SpiderUI = _G.SpiderUI or loadstring(game:HttpGet(SOURCE))()
_G.SpiderUI = SpiderUI

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Window = SpiderUI:CreateWindow({
	Title         = "SPIDER",
	Accent        = "VERSE",
	Subtitle      = "friendly neighborhood build",
	Theme         = "Classic",
	Size          = UDim2.fromOffset(720, 470),
	ToggleKey     = Enum.KeyCode.RightControl,
	FooterSubtitle = "with great power...",
})

----------------------------------------------------------------------
-- SPEED
----------------------------------------------------------------------
local Speed = Window:CreateTab("Speed", "walk, carry and lag-compensated movement")

local humanoid
local function withHumanoid(fn)
	local character = LocalPlayer.Character
	humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then fn(humanoid) end
end

Speed:CreateSection("Speeds")

Speed:CreateSlider({
	Text = "Normal Speed", Min = 16, Max = 250, Default = 70, Increment = 1,
	Flag = "NormalSpeed",
	Callback = function(value)
		if not SpiderUI.Flags.CarryMode then
			withHumanoid(function(h) h.WalkSpeed = value end)
		end
	end,
})

Speed:CreateSlider({
	Text = "Carry Speed", Min = 16, Max = 250, Default = 34, Increment = 1,
	Flag = "CarrySpeed",
	Callback = function(value)
		if SpiderUI.Flags.CarryMode then
			withHumanoid(function(h) h.WalkSpeed = value end)
		end
	end,
})

Speed:CreateToggle({
	Text = "Carry Mode", Description = "swap to carry speed while holding",
	Default = false, Flag = "CarryMode",
	Callback = function(on)
		withHumanoid(function(h)
			h.WalkSpeed = on and (SpiderUI.Flags.CarrySpeed or 34) or (SpiderUI.Flags.NormalSpeed or 70)
		end)
		Window:Notify({
			Title = "CARRY MODE",
			Text  = on and "Carry speed engaged." or "Back to normal speed.",
		})
	end,
})

Speed:CreateSection("Lagger")

Speed:CreateSlider({ Text = "Lagger Normal", Min = 16, Max = 250, Default = 45, Flag = "LaggerNormal" })
Speed:CreateSlider({ Text = "Lagger Carry",  Min = 16, Max = 250, Default = 29, Flag = "LaggerCarry" })
Speed:CreateToggle({ Text = "Auto Lagger",   Default = false,     Flag = "AutoLagger" })

----------------------------------------------------------------------
-- COMBAT
----------------------------------------------------------------------
local Combat = Window:CreateTab("Combat", "reach, prediction and target logic")

Combat:CreateSection("Targeting")

Combat:CreateDropdown({
	Text = "Target Priority",
	Options = { "Closest", "Lowest Health", "Highest Value", "Random" },
	Default = "Closest", Flag = "TargetPriority",
})

Combat:CreateSlider({ Text = "Hit Range", Min = 5, Max = 60, Default = 22, Suffix = " studs", Flag = "HitRange" })
Combat:CreateSlider({ Text = "Prediction", Min = 0, Max = 1, Default = 0.14, Increment = 0.01, Flag = "Prediction" })

Combat:CreateSection("Automation")

Combat:CreateToggle({ Text = "Auto Swing",  Default = false, Flag = "AutoSwing" })
Combat:CreateToggle({ Text = "Auto Parry",  Description = "reacts on wind-up frames", Default = false, Flag = "AutoParry" })
Combat:CreateToggle({ Text = "Spider-Sense", Description = "warn when someone locks on", Default = true, Flag = "SpiderSense" })

Combat:CreateButton({
	Text = "Reset Combat State", ButtonText = "RESET",
	Callback = function()
		Window:Notify({ Title = "COMBAT", Text = "State cleared." })
	end,
})

----------------------------------------------------------------------
-- MOVEMENT
----------------------------------------------------------------------
local Movement = Window:CreateTab("Movement", "swing lines, jumps and flight")

Movement:CreateSection("Web Swinging")

Movement:CreateToggle({ Text = "Web Swing",  Description = "hold to shoot a line and swing", Default = false, Flag = "WebSwing" })
Movement:CreateSlider({ Text = "Line Length", Min = 20, Max = 400, Default = 180, Suffix = " studs", Flag = "LineLength" })
Movement:CreateSlider({ Text = "Swing Force", Min = 1,  Max = 100, Default = 42, Flag = "SwingForce" })

Movement:CreateSection("Traversal")

Movement:CreateSlider({ Text = "Jump Power", Min = 20, Max = 350, Default = 50, Flag = "JumpPower",
	Callback = function(value)
		withHumanoid(function(h)
			h.UseJumpPower = true
			h.JumpPower = value
		end)
	end,
})
Movement:CreateToggle({ Text = "Infinite Jump", Default = false, Flag = "InfiniteJump" })
Movement:CreateToggle({ Text = "Wall Crawl",    Default = false, Flag = "WallCrawl" })
Movement:CreateToggle({ Text = "No Fall Damage", Default = true, Flag = "NoFallDamage" })

----------------------------------------------------------------------
-- STEAL
----------------------------------------------------------------------
local Steal = Window:CreateTab("Steal", "grab routes and auto-return")

Steal:CreateSection("Auto Steal")

Steal:CreateToggle({ Text = "Auto Steal",   Default = false, Flag = "AutoSteal" })
Steal:CreateSlider({ Text = "Steal Delay",  Min = 0, Max = 5, Default = 0.4, Increment = 0.1, Suffix = "s", Flag = "StealDelay" })
Steal:CreateDropdown({
	Text = "Return Route",
	Options = { "Direct", "Rooftops", "Web Line", "Safest" },
	Default = "Web Line", Flag = "ReturnRoute",
})

Steal:CreateSection("Filters")

Steal:CreateDropdown({
	Text = "Rarity Filter", Multi = true,
	Options = { "Common", "Rare", "Epic", "Legendary", "Mythic" },
	Default = { "Legendary", "Mythic" }, Flag = "RarityFilter",
})
Steal:CreateInput({ Text = "Ignore Player", Placeholder = "username", Flag = "IgnorePlayer" })

----------------------------------------------------------------------
-- SETTINGS
----------------------------------------------------------------------
local Settings = Window:CreateTab("Settings", "look and feel")

Settings:CreateSection("Appearance")

Settings:CreateDropdown({
	Text = "Suit", Description = "recolours the whole interface",
	Options = { "Classic", "Miles", "Noir", "Symbiote", "2099" },
	Default = "Classic", Flag = "Suit",
	Callback = function(value)
		Window:SetTheme(value)
		Window:Notify({ Title = "SUIT CHANGE", Text = value .. " equipped." })
	end,
})

Settings:CreateSlider({
	Text = "UI Scale", Min = 0.6, Max = 1.4, Default = 1, Increment = 0.05, Flag = "UIScale",
	Callback = function(value)
		Window.BaseScale = value
		Window.Scale.Scale = value
	end,
})

Settings:CreateSection("Menu")

Settings:CreateButton({
	Text = "Minimise To Emblem", ButtonText = "HIDE",
	Callback = function() Window:Minimize() end,
})

Settings:CreateButton({
	Text = "Unload Interface", ButtonText = "UNLOAD",
	Callback = function() SpiderUI:DestroyAll() end,
})

Settings:CreateParagraph(
	"About",
	"SpiderUI draws its webbing and emblem from primitive frames, so it has no "
		.. "asset dependencies and loads instantly. Right Control hides the menu."
)

----------------------------------------------------------------------
-- KEYBINDS
----------------------------------------------------------------------
local Keybinds = Window:CreateTab("Keybinds", "bind anything to a key")

Keybinds:CreateSection("Bindings")

Keybinds:CreateKeybind({ Text = "Toggle Menu",  Default = Enum.KeyCode.RightControl, Flag = "BindMenu" })
Keybinds:CreateKeybind({ Text = "Web Swing",    Default = Enum.KeyCode.Q, Flag = "BindSwing" })
Keybinds:CreateKeybind({ Text = "Carry Toggle", Default = Enum.KeyCode.C, Flag = "BindCarry",
	Callback = function()
		local toggle = Window.Elements.CarryMode
		if toggle then toggle:Set(not toggle:Get()) end
	end,
})
Keybinds:CreateKeybind({ Text = "Panic / Unload", Default = Enum.KeyCode.Delete, Flag = "BindPanic",
	Callback = function() SpiderUI:DestroyAll() end,
})

Keybinds:CreateLabel("Click a bind, then press a key. Backspace clears it.")

Window:Notify({
	Title = "SPIDER-SENSE",
	Text  = "Interface loaded. Right Control hides it.",
	Duration = 5,
})

return Window
