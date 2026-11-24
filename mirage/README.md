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

## DIRECT — buy it without the menu

This is the path to use when the dealer menu will not open. It needs no
menu, no NPC, no island check and no stock read.

The purchase is a remote call. The shop GUI is a middleman that makes
that call for you, so when the GUI is out of reach the call still is not.

1. **DIRECT** tab, the one it opens on. The fruit box already says
   `Kitsune`.
2. Press **Armed**.

While the buy remote is unknown it sweeps every remote in the place
named like a purchase, firing each with the fruit name and watching your
Beli. A remote that charges you is the buy remote; one that does not is
discarded. Once one charges, it stops sweeping and fires only that one,
every 1.5s, until the fruit is bought. The find is written back into the
config, so the next session starts locked on.

**Only the fruit name is ever sent, never a slot number.** A wrong guess
can fail. It cannot buy a different fruit.

If a stock source does exist, the gate uses it: nothing is fired until
the read actually shows your fruit. With no stock source the gate has
nothing to check and it fires on the timer instead, which is the whole
point.

Your Beli balance is the only honest confirmation available, so if no
numeric leaderstat can be read the sweep refuses to run and says so
rather than firing blind with no way to tell what happened.

**Sweep now**, **Attempt now**, **Reset what has been tried** and
**Report** are on the same tab. Report prints the target, the state, what
is locked, how many candidates exist and your balance.

## The flow through the menu

If the menu does open for you, this is the richer path: it shows all
seven slots with prices and lets you buy any of them on one tap.

The tool never moves your character. It opens the dealer's menu where you
stand and reads it.

1. **ISLAND** tab — check whether the dealer is in this server. Usually
   not. Turn on *Hop until the island is found* and leave it.
2. **STOCK** tab — the menu opens on its own. The first thing the opener
   tries is unhiding the shop frame already in your PlayerGui, which
   needs no NPC at all. Then the seven slots list with their Beli prices
   and a BUY button each.
3. **PICK** tab — tap a fruit to watch it, or type a name. The list is
   learned from what the shop actually prints, so it is never out of date
   with the game.
4. **STOCK** tab — arm *Instant buy*. From then on the reader polls every
   0.15s and the purchase goes out inside the read that sees your fruit,
   not on a later tick.

Pick Kitsune, arm it, walk away.

## Opening the menu

*Open the dealer menu automatically* is on by default. It tries five ways
in order, cheapest and least invasive first, and stops at the first one
that puts the shop on screen:

1. **Unhide the frame you already have.** A menu you have never opened is
   still sitting in your PlayerGui with `Enabled` or `Visible` off. The
   scanner finds the frame holding the most name+price label pairs
   whether or not it is showing, switches its chain on, and that is
   usually the whole job. No NPC, no prompt, no movement. Everything it
   switched on is switched back on unload.
2. **The learned open remote**, if you captured one.
3. **The dealer's ProximityPrompt**, after raising its
   `MaxActivationDistance` to 500 and clearing its line-of-sight and hold
   requirements locally, plus any ClickDetector on the model.
4. **The dealer's touch parts**, fired with `firetouchinterest` from your
   root, which is walking into it without walking.
5. **A button in your own GUI** whose name or text reads like a shop,
   fired through its live handler.

"the dealer model carries no prompt and no click detector" means step 3
had nothing to fire. That is a normal thing for an NPC to be, and the
other four steps do not care.

### When none of it works

CONFIG tab → **Scan and report**. It prints what is actually there: which
model won the dealer scan and how many prompts, click detectors and parts
it has; whether a visible shop frame exists; the top hidden shop frames
and their row counts; and which of the four executor functions you have.
That turns a guess into a line you can read.

If the report shows no hidden frame and the dealer has nothing on it, the
menu is being built on demand by a remote. CONFIG tab → **Watch: arm,
then open the menu**, open it by hand once, and the call that did it is
replayed from then on.

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

The ISLAND tab detects; it does not travel. There is no teleport in this
tool and a test asserts the character never moves. The stock is the same
on every server, so hopping never changes what is for sale: it only finds
a server where Mirage Island, and the dealer on it, exist.

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
boots the real bundle against it: price parsing, dealer and
shop resolution, GUI and remote stock reads, slot ordering, catalogue
learning, both buy paths, the learner adopting a simulated purchase and
capturing its token, affordability, restock detection, the instant buy
firing inside the read that sees the fruit land, no double buy, poll
tightening while armed, 240 frames with everything on, the shop closing
mid-run, the auto-opener firing the prompt and standing down once the
menu is up, its retry rate limit, a guard that the character never moves,
a dealer stripped of its prompt still opening through the hidden frame,
the reveal being reversible, the open watch capturing a remote, the
direct sweep rejecting a loud decoy that charges nothing and locking the
one that does, never sending a slot number, the stock gate holding and
releasing fire, a guard that the character never moves, and a full mobile
pass. 114 checks. Needs `pip install lupa`.

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
src/15_headless.lua  buying with no menu: sweep, lock, fire
src/16_island.lua    Mirage Island detection, no travel
src/17_session.lua   anti-afk, servers, rejoin, panic
src/18_menu.lua      the six tabs
src/19_main.lua      boot, driver, teardown
```
