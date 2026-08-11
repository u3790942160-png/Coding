# Veltrex Hub — rebuilt interface

The original release was a single 129 KB line with its interface welded into its
logic: `startAutoLeft` reached out to `autoLeftSetVisual` and `_updateMobileAutoLeft`,
the steal engine wrote directly into a `TextLabel`, and adding a control meant
threading a new `setXVisual` upvalue through the whole file.

This repository splits it in two and replaces the interface entirely.

```
src/core.lua    all gameplay logic, zero GUI code
src/ui.lua      the new interface, zero gameplay code
build.py        bundles both into dist/VeltrexHub.lua
test/           a Roblox API mock and a smoke test that runs the bundle
```

Run `dist/VeltrexHub.lua`. Rebuild it with `python3 build.py` after editing
anything in `src/`.

## The interface

A console, not a settings panel: tabs across the top, content across the full
width, flush rows on hairlines, no rounded corners anywhere, monospace
throughout, amber phosphor on warm black.

- **STATUS** — a four-column telemetry block (fps, ping, speed, profile), four
  command buttons, and the five channels you reach for most.
- **SPEED** — profile cells (Norm / Carry / Lag / LagC), auto switch, and a
  meter for each rate.
- **COMBAT** — Auto Bat, Auto Swing, Bat V2, Anti-Desync, the two counters, and
  meters for chase speed, hover height, turn rate, hit range and swing delay.
  Those five were hard-coded constants before.
- **STEAL** — the engine, normal/semi mode, every range, a live podium count and
  a manual rescan.
- **MOVE** — the two auto paths, drop and drop mode, TP down, auto TP, the TP
  height, and the character channels.
- **KEYS** — every binding, rebindable, keyboard or gamepad.
- **CONFIG** — six console phosphors, three independent scale meters, position
  lock, strip and keypad visibility, layout reset and a clean unload.

The controls carry the same idea:

- **Toggles are ON/OFF cells** with a lamp in the left gutter, so scanning the
  gutter tells you what is live without reading any labels.
- **Numbers are twenty-cell meters**, dragged or clicked across the cells, with
  the value as a monospace readout you can also type into.
- **Sections are a label and a rule** out to the right edge, not a boxed card.
- **Modes and keybinds are bracketed cells**; a listening keybind blinks.

Also new:

- **Filter** — the `>` line at the top narrows every row across all tabs as you
  type, collapses empty sections, dims tabs with no matches and jumps to a tab
  that has some.
- **Status strip** — one 420x26 line: what the hub is doing, a segmented
  progress meter, a percentage and fps/ping/speed. Draggable, scalable, hideable.
- **Keypad** — a 3x4 touch grid, one draggable panel rather than twelve
  independently dragged buttons, each key lit from the same state the console
  reads, so the two cannot disagree.
- **Log lines** replace silent failures — bottom-left terminal output when a
  channel changes, a steal lands, or your executor is missing something.
- **Unload** stops every loop, disconnects every connection, destroys the GUIs
  and writes the config. Re-running the script unloads the previous copy first,
  so it no longer stacks duplicate interfaces. The header `X` asks once first;
  `_` collapses to a small bracket stub.

Defaults: `LeftCtrl` toggles the console, `Q` carry speed, `R` lagger, `X` drop,
`F` TP down, `T` instant reset, `Z`/`C` auto paths, `E` auto bat, `V` bat V2,
`B` anti-desync.

## How the two halves talk

Core owns the state and announces changes; the interface listens and renders.

```lua
Core.setFeature("autoBat", true)   -- handles conflicts, starts the loop, emits
Core.on("feature", function(id, on) ... end)
```

Features are declared in one table with their conflicts, so mutual exclusion is
data rather than code. The original hand-wrote "turn off bat V2, update its
desktop visual, update its mobile visual, then stop its loop" at each of the
five places bat V2 could be switched off; missing one is what made toggles fall
out of sync. Enabling anything now goes through `setFeature`, and every widget
bound to that feature updates itself.

Config lives in `VeltrexHub.json` and covers speeds, ranges, aimbot tuning,
modes, keybinds, which features were on, and interface preferences. Settings from
the original `VeltrexHubConfig.json` are imported on first run.

## Behaviour changes

Everything from the original is here, with these deliberate differences:

- **The remote kill-switch is gone.** The original polled a pastebin every three
  seconds and called `LP:Kick(...)` followed by `task.wait(999999)` if your user
  ID appeared on it. That is a switch pointed at you, held by whoever edits that
  paste, so it is not in this build.
- **TP height is wired up.** The original had a "TP Height" box that was saved,
  loaded and never read — TP Down always used `-7`. The slider now sets the Y
  level it teleports to, defaulting to `-7`.
- **Speed is shown on the status strip** instead of a `BillboardGui` floating
  over your head, which was interface code living inside the character.
- **Aimbot constants are meters.** Chase speed, hover height, turn rate, hit
  distance and swing cooldown were literals in the middle of the aimbot loops.
- **No-collide is a toggle and runs five times a second** instead of walking
  every player's descendants on every physics step.
- **Loops use generation tokens**, so toggling something off and straight back on
  can no longer leave two copies of its loop running.
- **`getconnections` is checked once** and reported through a toast rather than
  silently making auto steal do nothing.

## Tests

```
python3 build.py && lua5.4 test/smoke.lua
```

`test/roblox_mock.lua` is a small stand-in for the engine — instances, signals,
a coroutine scheduler for `task.*`, the datatypes, plus fixtures for a character,
an opponent and a plot with steal prompts. `test/smoke.lua` loads the real
bundle against it and drives 23 checks: every feature on and off, conflict
handling, value clamping, every action, every keybind, the render and physics
loops with a live character, the aimbots locking onto an opponent, the steal
engine driving a prompt to progress, clicking every control in the interface,
search, config persistence and unload.

It is a smoke test, not a simulator: it proves the script loads, builds and
survives being used. Whether the aimbot lands a hit is still something only
Roblox can tell you.
