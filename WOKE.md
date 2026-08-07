# WOKE

`WokeHub.lua` is the script to run: the WOKE hub with every button, toggle,
value box and keybind wired to the feature logic from `Ace_source.lua`.
None of the Ace source's own GUI code is included — only its logic.

## Files

| File | Purpose |
| --- | --- |
| `WokeHub.lua` | **Generated.** The single script to execute. Don't edit by hand. |
| `WokeHub_UI.lua` | The WOKE UI layout + the wiring that binds it to the logic. |
| `Ace_source.lua` | Unchanged Ace source; the logic is extracted from it at build time. |
| `tools/build_wokehub.py` | Builds `WokeHub.lua` from the two files above. |
| `tools/test/` | Roblox API mock + a test that clicks the built UI and checks the logic reacts. |

```
python3 tools/build_wokehub.py     # rebuild WokeHub.lua
lua5.1 tools/test/test_wokehub.lua # 76 checks over the wiring
```

## What the build does

Only the logic ranges of `Ace_source.lua` are copied in:

* `1–3375` — services, config save/load, speed modes, drop brainrot, TP down,
  animation packs, infinite jump, anti-ragdoll, auto steal (normal + semi),
  aimbots (normal / anti-bypass / anti-desync), counters, safe mode,
  anti-bodylock, no player collision, auto left/right, ragdoll countdown.
* `5350–6018` — ESP, sky presets, stretch res, anti-lag, nuke optimiser,
  FOV, no cam collision.
* `7509–7586` — auto-TP restore helpers and keybind repair.

Everything else in that file is its menu GUI (rows, pages, lightning FX, steal
bar, intro, its own mobile buttons) and is left out.

The state and functions the UI needs are promoted from chunk-locals to globals
during the build — the Ace chunk is already near Lua's 200-local limit, and the
UI lives inside its own function so it gets a fresh budget.

## Control map

**Movement** — Normal/Carry/Lagger speed boxes, MODE rows (Normal↔Carry and the
lagger modes), Auto Carry Speed, Drop (arrow selects JUMP = hop-and-slam or
STAND = plain floor teleport), TP Down, Auto TP Down + height, Infinite Jump,
Anti Ragdoll, Unwalk.

**Combat** — steal Radius and SEMI Range, Auto Steal (arrow selects
NORMAL/SEMI), Bat Aimbot (arrow selects NORMAL/BYPASS) with speed box, Auto
Swing, Mirror TP, TP Bat = anti-desync bat (arrow selects SWING/NO SWING), Auto
Left/Right, Bat Counter, Medusa Counter, Reset After Med, Insta Reset, Safe
Mode, Anti Bodylock, No Player Collision.

**KBM / CTRL** — the same nine actions plus the UI toggle, bound separately for
keyboard and gamepad. Click a row to listen, click the round button to clear,
Escape cancels. Keyboard binds live in the Ace config; controller binds are
saved alongside them under `adaptControllerKeybinds`.

**VISUAL** — ESP, Show Tracer, Ragdoll Countdown, Custom Sky (all 24 Ace
presets), Anim Pack (the full Ace pack list), Try Hard Animation, Stretch Res,
Anti-Lag, Nuke Optimiser, FOV Change + value, No Cam Collision.

**SETTINGS** — mobile button size/hide/circle/move/reset, intro + intro song,
background and button-image galleries, colour theme, UI scale, steal bar size,
save and reset-all.

**Mobile buttons** — Drop Brainrot, Auto Left/Right, Bat Aimbot, TP Bat, TP
Down, Carry Speed, Lagger Mode, Instant Reset. They light up from the real
state, and drag to reposition when Move Buttons is on.

## Differences from the original AdaptHub mock-up

The hub is named WOKE: the ScreenGui is `WokeHub`, and the banner and header
wordmarks are drawn as WOKE text in the same slots and styling the logo art
occupied. Colours, layout and animations are unchanged.

* Arrows only appear on rows that actually have a selector under them.
* Rows without an Ace counterpart were replaced with ones that have logic
  behind them: `Lock Radius` → `No Player Collision`, and `Safe Mode`,
  `Auto Carry Speed`, `Nuke Optimiser`, `No Cam Collision` were added.
* Steal Bar Size is kept and saved, but the Ace steal-bar GUI isn't part of this
  script, so it only takes effect if a `StealBarGui` exists.

## Fixed after the first build

* Mobile buttons were scaled by a `UIScale` on their full-screen holder, which
  scaled their screen positions too and pulled them off the right edge. Each
  button now scales itself, so only its size changes.
* A touch that started elsewhere and was released over a mobile button fired
  that button's action; a press now has to start on the button.
* The floating open button could not be dragged — its image button covered the
  frame the drag handler was attached to — and a drag that ended over it
  re-opened the menu. Dragging now runs off the button, with a deadzone.
* The hub kept its window scale and background index under the Ace menu's
  config keys, so an existing Ace config loaded this UI at that menu's scale
  (0.52) with an index into a different image list. It now stores
  `wokeUiScale` and `wokeBackground` of its own.
* A gamepad press could match a keyboard binding; controller input now only
  matches controller binds.
* Re-running the script stacked a second menu; an existing hub is removed first.
* A keybind row waiting for input lost its "..." prompt on any UI re-sync, and
  Escape only cancelled for the matching device.
* Mobile button labels had no size constraint and overflowed their 58px
  buttons.
* Button Size % accepted up to 200% while the saved config clamps at 135%, so
  the value moved on its own after a reload.
