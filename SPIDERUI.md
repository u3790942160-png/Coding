# SpiderUI

A Spider-Man themed interface library for Roblox. Everything is drawn from
primitive frames — the webbing, the emblem, the glows — so there are no asset
IDs to break and nothing to download at runtime.

| File | What it is |
| --- | --- |
| `SpiderUI.lua` | The library. Returns a table; drop it in or `loadstring` it. |
| `SpiderUI_Example.lua` | A full six-tab menu wired to real humanoid properties. |
| `preview/spiderui-preview.html` | Browser preview of the exact layout and all five suits. |

## Getting started

```lua
local SpiderUI = loadstring(game:HttpGet("<your-host>/SpiderUI.lua"))()

local Window = SpiderUI:CreateWindow({
    Title     = "SPIDER",    -- white half of the wordmark
    Accent    = "VERSE",     -- accent-coloured half
    Subtitle  = "v1.0",
    Theme     = "Classic",   -- Classic | Miles | Noir | Symbiote | 2099
    Size      = UDim2.fromOffset(720, 470),
    ToggleKey = Enum.KeyCode.RightControl,
})

local Tab = Window:CreateTab("Speed", "walk and carry speeds")

Tab:CreateSection("Speeds")

Tab:CreateSlider({
    Text = "Normal Speed", Min = 16, Max = 250, Default = 70,
    Flag = "NormalSpeed",
    Callback = function(value)
        local humanoid = game.Players.LocalPlayer.Character
            and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid.WalkSpeed = value end
    end,
})
```

`Size` should be given in offsets — the corner webs are laid out in pixels and
fall back to 720×470 if you pass a scale-based size.

## Controls

Every constructor takes a config table and returns a handle with `:Set(value)`
and `:Get()`. Pass a `Flag` and the value is mirrored into `SpiderUI.Flags[flag]`
and the handle into `Window.Elements[flag]`.

| Constructor | Notable options |
| --- | --- |
| `Tab:CreateSection(text)` | — |
| `Tab:CreateLabel(text)` | returns `:Set(text)` |
| `Tab:CreateParagraph(title, body)` | grows to fit its text |
| `Tab:CreateButton{}` | `ButtonText`, `Callback` |
| `Tab:CreateToggle{}` | `Default`, `Description`, `Callback(on)` |
| `Tab:CreateSlider{}` | `Min`, `Max`, `Increment`, `Suffix`, `Callback(value)` |
| `Tab:CreateDropdown{}` | `Options`, `Multi`, `:Refresh(newOptions)` |
| `Tab:CreateKeybind{}` | `Callback` on press, `Changed` on rebind, Backspace clears |
| `Tab:CreateInput{}` | `Placeholder`, `Callback(text, enterPressed)` |

## Window

```lua
Window:CreateTab(name, description)
Window:SelectTab(tab)
Window:SetTheme("Miles")   -- repaints every themed property live
Window:Notify({ Title = "SPIDER-SENSE", Text = "...", Duration = 4 })
Window:Toggle(visible)     -- omit the argument to flip
Window:Minimize()          -- collapses to a draggable spider emblem
Window:Destroy()
SpiderUI:DestroyAll()
```

The toggle key hides and restores the window. Minimising leaves a draggable
emblem on screen; click it (rather than drag it) to bring the menu back.

## Suits

`Classic` red-and-blue, `Miles` black with neon cyan, `Noir` greyscale with a
blood-red accent, `Symbiote` oily black and white, `2099` cyber red on teal.
Theming is registry-driven: each themed property is recorded as it's created,
so `SetTheme` tweens the entire interface rather than rebuilding it.

## Notes

- Roughly 1,000 instances for the six-tab example, 298 of which are static web
  strands. Nothing runs per-frame; the only background task is the idle
  spider-sense pulse on the title emblem every four seconds.
- The GUI parents itself through `gethui()` / `syn.protect_gui` when available
  and falls back to `CoreGui`, then `PlayerGui`.
- Mobile is detected via `TouchEnabled and not KeyboardEnabled` and the window
  scales to 0.78; override with the `Scale` config field.
