# olliE / Lord's Court — Touch Football

A full client toolkit for Roblox Touch Football, built mobile first. One
bundled file, a tabbed draggable menu, draggable on-screen buttons, and
keyboard plus controller binds for every main feature.

## Load

```lua
getgenv().LC_URL = "https://raw.githubusercontent.com/u3790942160-png/Coding/claude/ollie-character-setup-4q41cv/dist/ollie_tf.lua"
loadstring(game:HttpGet(getgenv().LC_URL))()
```

Setting `LC_URL` first is optional but it is what lets Rejoin, Hop Server
and Panic Staff re-execute the script after the teleport, on executors
that expose `queue_on_teleport`.

`// executor territory: the namecall hook and the ball velocity writes are
both visible to server side checks, so run this on an alt, not your main.`

Menu key is `Insert`. `End` is Panic Eject — it unhooks, restores
collisions, unfreezes the ball and removes every GUI.

## What ships unset, and why

There is no Touch Football dump in this project. No offsets, no remote
names, no instance paths were handed over, so none were invented. Every
game-specific value lives in one block in `src/02_cfg.lua` under
`Cfg.target`, and every one of them is empty.

Three tiers run side by side:

| tier | what it means | where it comes from |
|---|---|---|
| confirmed | you captured it this session | Capture Goal, Pin Ball, calibration |
| derived | scored from engine-visible structure | the resolver |
| unknown | not found | the feature gates itself and says so once |

Nothing is gated on the whole module. A missing kick remote does not stop
the aimbot; it just means the aimbot uses the physics or touch backend
instead.

### Filling the unknowns

**Ball** — the resolver scores every unanchored, roughly spherical,
non-character part in the workspace and takes the best. If it picks wrong,
CONFIG tab → look at the ball → **Pin ball under crosshair**.

**Goals** — the scanner looks for names containing goal / net / posts and
orients each mouth toward the other goal. If the pitch does not name them
that way: stand in the mouth, face the pitch, CONFIG tab → **Capture Own
Goal** / **Capture Enemy Goal**. A capture outranks anything scanned.

**Kick remote** — CONFIG tab → arm **Remote spy** → kick the ball once →
the log shows the call with its argument types. Put the name in **Kick
remote** and pick the matching **Kick arg shape**:

| shape | call the game makes |
|---|---|
| `dir_power` | `FireServer(Vector3 unitDirection, number power)` |
| `vector` | `FireServer(Vector3 velocity)` |
| `cframe` | `FireServer(CFrame aim, number power)` |

**Quest remote** — same spy, hand in one quest, copy the name.

**Deny remotes** — same spy, take a deny, copy the name into **Deny
remotes**. Block Kick Deny Events swallows those calls.

**Calibration** — CONFIG tab → **Run calibration**. It measures live
gravity, the velocity decay this build applies to the ball, and how many
studs per second one power unit buys. Until it runs, the power sliders are
raw studs per second and the readout says `uncalibrated`.

## Backends

Features never pick a backend. They ask for a kick and the manager takes
the first one that works:

| backend | needs | notes |
|---|---|---|
| remote | `kickRemote` + `kickArgShape` filled | authoritative, preferred |
| physics | the ball unanchored | direct assembly write, needs network ownership to stick |
| touch | `firetouchinterest` in the executor | fires the game's own kick handler at a distance — this is what Reach is |

The CONFIG tab shows which of the three are live right now.

## Tabs

**REACH** — Reach, Pro Reach (natural), Control Reach (easier), radius,
trigger range, pulse rate, Reach Priority (nearest / ball-to-goal /
teammate-safe), Ball Hold with distance and height, Adapt High MS with
studs-per-ms and cap.

**SKILLS** — Sneaky (air only, auto adapt, power, lift, manual flick),
Pokers with speed and power, Auto Juggle (reach, height, sticky), Ground
Shots with lift.

**AIMBOT** — Aimbot, Aimlock with speed, FOV, fire rate, power, speed,
gravity scale, miss chance, Curve Aimbot, Auto Adapt Curve, Random Curve,
curve amount, Top Corner Mode with inset, Auto Detect Goal, Auto Nero,
Manual Nero with power/lift/spin, Auto Header with range and power.

**AIMPASS** — smart receiver scoring, Teammates Only, pass range, Through
Balls with lead, min and max pass power, max lob height, Curve AimPass.

**KEEPER** — Auto GK (air saves), Auto GS (ground saves), dive speed, GK
touch reach, predict window, Panic Reach with radius, Block Kick Deny
Events.

**SPECIAL** — Phase Enemy (Look At / Selected), Anti-Phase, Frame Player
with crosshair select, Bring Ball, Freeze/Unfreeze Ball, Delete Ball,
Ball Time with scale, Dunk with range, Goal Farm, Save Farm, Trick Oms
(Rainbow Flick, Sombrero, Fake Shot).

**VISUALS** — Ball ESP with outline, tracer and distance, Ball Trail, RGB
Character with neon and speed, Rainbow Boot Trail, Time of Day, Spoof
Marker for ping, CPU and sent.

**CHARACTER** — R6 Character (local rig, procedural walk), Use Own Avatar,
hat and hair by asset id, Remove All Accessories.

**BINDS** — every action, keyboard box takes a key press, controller box
cycles the pad buttons. Defaults: Reach `R`/`R1`, Sneaky `X`/`L1`, Aimbot
`T`/`Y`, AimPass `G`/`X`, Auto GK `V`/`L2`, Phase `F`/`R2`, Juggle `J`,
Pokers `P`, Nero `N`, Bring `B`, Freeze `H`, Panic `End`.

**SETTINGS** — Anti-AFK, Notifications, Auto Complete Quest, Force
Respawn, Rejoin, Panic Eject, Auto Best Server, max ping, minimum free
slots, Hop Server (low ping), Panic Staff with group id / rank / name
list, on-screen buttons with size, shape (shield, circle, square) and
transparency, reset positions.

**CONFIG** — resolver status, rescan, pin ball, capture goals, swap goals,
calibration, remote spy, the target value boxes, save / load / reset JSON
configs, executor capability table.

## Mobile

Everything is touch first. Sliders have a 34px invisible grab strip over
the 6px track, rows grow to 42px, the window sizes to 94% of the viewport
capped at 600px, tabs scroll horizontally, and dropdowns expand inline
rather than overlaying. The on-screen buttons drag with a 6px slop so a tap
fires and a drag moves, and positions persist per button in the config.

## Local-only, by construction

These change your client and nothing else. Said once here, not repeated in
the UI: Delete Ball, R6 Character, RGB Character, boot trails, Time of Day,
Use Own Avatar, hat and hair, Remove All Accessories, Phase and Anti-Phase
collision writes.

## Build

```bash
python3 tools/build.py     # src/ -> dist/ollie_tf.lua, syntax checks every module
python3 tools/test.py      # boots the bundle in a mock Roblox runtime
```

`tools/build.py` parses each module and the bundle. `tools/test.py` builds
a fake pitch (ball, two goals, four players, two teams), boots the real
bundle against it, and asserts on the solvers and the drivers: ballistic
round trip, both arcs, out-of-range, parabola/plane crossing, top-corner
geometry, shot direction, pass selection, keeper prediction, 240 frames
with every feature enabled, ball destroyed mid-match, and a full mobile
pass. Needs `pip install lupa`.

## Layout

```
src/01_env.lua       executor capability probe
src/02_cfg.lua       settings + the unset target block
src/03_util.lua      signal, maid, clamp, json io
src/04_svc.lua       services and character accessors
src/05_amath.lua     pure aim math, no game reads
src/06_theme.lua     Lord's Court palette and ornaments
src/07_notify.lua    toast stack
src/08_ui.lua        widget library
src/09_binds.lua     keyboard + gamepad
src/10_touchui.lua   on-screen buttons
src/11_resolve.lua   ball / goal / team / remote discovery, remote spy
src/12_backend.lua   remote, physics and touch ball control
src/13_calib.lua     gravity, drag and power measurement
src/14_reach.lua     reach
src/15_skills.lua    sneaky, pokers, juggle, ground shots
src/16_aimbot.lua    shot solving
src/17_aimpass.lua   passing
src/18_keeper.lua    goalkeeping
src/19_special.lua   phase, frames, farms, ball handling, tricks
src/20_visuals.lua   esp, trails, rgb, clock, spoof marker
src/21_charmod.lua   local R6 rig and appearance
src/22_settings.lua  anti-afk, servers, staff, quests, panic
src/23_menu.lua      every tab
src/24_main.lua      boot, drivers, teardown
```
