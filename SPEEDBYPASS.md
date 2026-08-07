# Speed Bypass

`SpeedBypass.lua` is a standalone script — run it on its own. It does not need
WOKE or any other script, and it stays out of their way if they are running.

```
lua5.1 tools/test/test_speedbypass.lua   # 58 checks over the panel + engine
```

## How it works

A duel script that runs you at 59 drives the humanoid, so it is limited by how
fast the humanoid is allowed to walk — that is the cap you hit. This leaves
that loop completely alone. Every frame it takes whatever direction you are
already holding and moves the root part the *extra* distance itself, so you
cover more ground without the humanoid ever reporting a higher speed.

It never touches `WalkSpeed`, never writes velocity, and never replaces
anyone's movement loop, which is why it stacks on top of whatever speed script
you already have instead of fighting it.

Each frame's extra travel is walked in hops of at most 3.5 studs with a raycast
in front of every hop, so you slide along the ground and stop at walls instead
of punching through them. The boost eases in and out over about a third of a
second rather than snapping, and one frame's catch-up is capped at 1/30s of
travel so a frame hitch cannot fling you across the map.

## Power

2000 power buys one extra stud/second, so the default **100000 is +50 studs/s**
on top of whatever you were already running. Clamped to 1000–1000000, i.e.
+0.5 to +500 studs/s. Anything that is not a number leaves the power alone.

| Power | Bonus | Running at 59.5 you get |
| --- | --- | --- |
| 20000 | +10 | 69.5 |
| 100000 | +50 | 109.5 |
| 250000 | +125 | 184.5 |
| 1000000 | +500 | 559.5 |

## The panel

268×232, its own `ScreenGui` (`SpeedBypassGui`). Four rows:

* **Main Feature** — the ENABLED / DISABLED pill.
* **Power** — the dial above.
* **Keybind** — defaults to **CapsLock**. Click to listen, the round button
  clears it, Escape cancels, Backspace/Delete clears.
* **Speed** — your live measured speed, and the bonus while it is on.

Drag it by the title bar. `×` collapses it to a small **SPEED BYPASS** pill
that reopens it — the pill drags too, and its outline lights up while the
bypass is on, so you can tell at a glance with the panel closed.

## When it stands down

It **pauses** — it does not switch off — whenever something else is steering
your character, and resumes on its own the moment that clears:

* ragdolled, seated, platform-standing, dead, or standing still
* any WOKE aimbot, or a WOKE Safe Mode lock (duel countdown / carrying)
* `_G.SpeedBypassSuspend = true`, for any other script that needs it to hold

Two systems fighting over your root part every frame would tear you between two
positions, which is why it yields rather than competing.

## Settings

Saved to `SpeedBypass.json` through the executor's `writefile`/`readfile` if it
has them; without them the script still runs, it just does not remember
anything. Stored: enabled state, power, keybind, whether the panel is open, and
where the panel and pill were dragged to.

## Globals it publishes

| Global | Purpose |
| --- | --- |
| `_G.SpeedBypassEnabled()` | Is it on |
| `_G.SpeedBypassSetEnabled(bool)` | Turn it on or off |
| `_G.SpeedBypassBonus()` | Current bonus in studs/second |
| `_G.SpeedBypassStep(dt)` | One frame of movement, for testing |
| `_G.SpeedBypassSuspend` | Set `true` to pause it from another script |
