# mirage stock — Blox Fruits dealer watch and instant buy

Pick a fruit. The moment the Mirage dealer is holding it, it is bought
with Beli on the same read that saw it land.

## Load

```lua
getgenv().MS_URL = "https://raw.githubusercontent.com/u3790942160-png/Coding/claude/ollie-character-setup-4q41cv/mirage/dist/mirage_stock.lua"
loadstring(game:HttpGet(getgenv().MS_URL))()
```

Menu key is `Insert`. `End` is panic eject. Setting `MS_URL` first is what
lets a hop or a rejoin re-execute the script after the teleport.

## The flow

1. **ISLAND** tab — check whether Mirage Island is in this server. It is
   not usually. Turn on *Hop until the island is found* and leave it.
2. **STOCK** tab — once the dealer is there, press *Open the dealer's
   shop*, then *Read stock now*. The seven slots list with their Beli
   prices and a BUY button each.
3. **PICK** tab — tap a fruit to watch it, or type a name. The list is
   learned from what the shop actually prints, so it is never out of date
   with the game.
4. **STOCK** tab — arm *Instant buy*. From then on the reader polls every
   0.15s and the purchase goes out inside the read that sees your fruit,
   not on a later tick.

Pick Kitsune, arm it, walk away.

## Beli only

There is no Robux path, on purpose. A purchase can go out two ways: the
learned remote, or by firing the shop row's own button handler. The button
does not say which currency it spends, so a tool that used it for a Robux
purchase would be spending real money on a guess. Robux prices are read
and shown; nothing here spends them.

## What ships unset

No Blox Fruits dump was handed over, so no offsets, remote names, instance
paths, fruit names or prices are baked in. Mirage stock rotates about
every two hours and the game ships updates, so a baked table would read as
real while being wrong. Everything game specific sits in `Cfg.target` in
`src/02_cfg.lua`, empty, and is filled one of three ways:

**The dealer** is found by scanning NPCs: a model with a Humanoid, no
Player, a name or proximity prompt that reads like a shop. Wrong pick →
CONFIG tab → *Pin the NPC I am looking at*.

**The stock** is read two ways, tried in order. If a stock RemoteFunction
has been found, it is invoked and the payload normalised structurally —
anything with a name-ish key and a price-ish key becomes a row. Otherwise
the open shop GUI is read: the frame holding the most name+price label
pairs is the stock list, each child row gives a name, a Beli price, a
Robux price and its buy button. Prices are parsed, not assumed:
`$5,000,000`, `3.4M`, `12.5k` and `R$ 3,000` all come out right.

**The purchase remote** is learned. CONFIG tab → *Watch: arm, then buy one
fruit* → buy one by hand. It watches your balance drop, matches the drop
against a stock line to work out which fruit you bought, and reads the
remote and its argument shape off the call the game actually made,
including the currency token for shapes that take one. Calls this tool
makes are skipped, so it cannot train on itself.

Buying is Watch-only. Firing an unknown RemoteEvent to see whether it buys
something would spend your Beli to find out, so the prober only touches
RemoteFunctions that read.

| buy shape | call the game makes |
|---|---|
| `name` | `FireServer(string fruitName)` |
| `name_cur` | `FireServer(string fruitName, string currencyToken)` |
| `slot` | `FireServer(number slotIndex)` |
| `slot_cur` | `FireServer(number slotIndex, string currencyToken)` |
| `bare` | `FireServer()` with the server reading a selection it holds |

## When nothing buys

CONFIG tab → **Why nothing buys** gives five rows — dealer npc, shop gui,
stock read, buy path, currency — and a verdict naming which link is
broken. Buying needs either a learned remote or a readable row with a
button plus `getconnections` in your executor; the diagnosis says which
one you are missing.

## Hopping

The stock is the same on every server, so hopping never changes what is
for sale. It only finds a server where Mirage Island, and the dealer on
it, exist. That is the only thing the hop is for, and the ISLAND tab says
so on the tab itself.

## Mobile

Same touch-first build as the rest: 42px rows, a 34px invisible grab strip
over each slider, inline dropdowns, a window at 94% of viewport capped at
600px, and six draggable on-screen buttons — read, buy, arm, island, hop,
menu — whose size, shape and positions persist.

## Build

```bash
python3 tools/build.py    # src/ -> dist/mirage_stock.lua, syntax checks every module
python3 tools/test.py     # boots the bundle in a mock Roblox runtime
```

`tools/test.py` builds a fake Mirage dealer with a seven slot shop GUI, a
buy RemoteEvent, a stock RemoteFunction, leaderstats and a decoy NPC, then
boots the real bundle against it. 70 checks: price parsing, dealer and
shop resolution, GUI and remote stock reads, slot ordering, catalogue
learning, both buy paths, the learner adopting a simulated purchase and
capturing its token, affordability, restock detection, the instant buy
firing inside the read that sees the fruit land, no double buy, poll
tightening while armed, 240 frames with everything on, the shop closing
mid-run, and a full mobile pass. Needs `pip install lupa`.

## Layout

```
src/01_env.lua       executor capability probe
src/02_cfg.lua       settings + the unset target block
src/03_util.lua      signal, maid, json io
src/04_svc.lua       services, gui and npc accessors
src/05_theme.lua     mirage palette and ornaments
src/06_notify.lua    toast stack
src/07_ui.lua        widget library, incl. the stock action row
src/08_binds.lua     keyboard + gamepad
src/09_touchui.lua   on-screen buttons
src/10_resolve.lua   dealer, shop frame, remotes, namecall spy
src/11_stock.lua     stock readers, price parsing, restock diffing
src/12_catalog.lua   the learned fruit list
src/13_learn.lua     purchase watch, stock probe, diagnosis
src/14_buy.lua       buying and the instant engine
src/15_island.lua    Mirage Island detection and travel
src/16_session.lua   anti-afk, servers, rejoin, panic
src/17_menu.lua      the five tabs
src/18_main.lua      boot, driver, teardown
```
