# AdaptHub

`AdaptHub.lua` is the script to run: the AdaptHub polished UI with every button,
toggle, slider and keybind wired to the feature logic from `Ace_source.lua`.
None of the Ace source's own GUI code is included — only its logic.

## Files

| File | Purpose |
| --- | --- |
| `AdaptHub.lua` | **Generated.** The single script to execute. Don't edit by hand. |
| `AdaptHub_UI.lua` | The AdaptHub UI layout + the wiring that binds it to the logic. |
| `Ace_source.lua` | Unchanged Ace source; the logic is extracted from it at build time. |
| `tools/build_adapthub.py` | Builds `AdaptHub.lua` from the two files above. |
| `tools/test/` | Roblox API mock + a test that clicks the built UI and checks the logic reacts. |

```
python3 tools/build_adapthub.py     # rebuild AdaptHub.lua
lua5.1 tools/test/test_adapthub.lua # 62 checks over the wiring
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

* Arrows only appear on rows that actually have a selector under them.
* Rows without an Ace counterpart were replaced with ones that have logic
  behind them: `Lock Radius` → `No Player Collision`, and `Safe Mode`,
  `Auto Carry Speed`, `Nuke Optimiser`, `No Cam Collision` were added.
* Steal Bar Size is kept and saved, but the Ace steal-bar GUI isn't part of this
  script, so it only takes effect if a `StealBarGui` exists.
