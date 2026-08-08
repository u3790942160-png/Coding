# Spidey Hub

`Ace_SpiderVerse.lua` is your uploaded source with the interface rebuilt: the
sidebar layout from the reference screenshot, a Spider-Man visual identity, and
the menu rebranded to **Spidey Hub**.

Load it exactly like the original — it is a single self-contained script.

## Layout

| | Before | After |
| --- | --- | --- |
| Window | 356 × 536 portrait | 640 × 460 landscape |
| Navigation | horizontal tab strip under the header | sidebar rail on the left |
| Page context | none | page title + blurb above the rows |
| Rows | 34 px | 40 px, roomier label |
| Minimised | "ACE" pill | circular spider emblem |

The sidebar holds a `NAVIGATION` label, the five tabs (Movement, Combat,
Keybinds, Visuals, Settings) with a red indicator bar that slides to the active
one, and a player card pinned to the bottom.

## Theme

Everything is drawn from `Frame` primitives — there are no image assets, so
nothing can fail to load:

- **Webbing** — two quarter-webs with their hubs pinned exactly on opposite
  corners, spokes radiating out and ring chords sagging back toward the hub.
- **Emblem** — eight legs that bend at a knee, plus abdomen and head. The knee
  is what keeps the silhouette readable at small sizes.
- **Spider-sense** — a ring pulses out of a toggle knob when it turns on. It
  fires only on a real off→on flip, so loading a config doesn't set off every
  toggle at once.
- Red header bloom, accent section rules, red value chips, and a hover rail on
  each row.

## What was not touched

Every row builder — `baseRow`, `toggleRow`, `textboxRow`, `dropdownRow`,
`section`, `_G.AceActionToggleRow` — keeps its name, arguments and return
values. `pages`, `addPage`, `setTab`, `Content`, `Close` and
`AceLockTopButton` are all still defined with the same meanings. No game logic,
callback or feature code was modified; the diff is confined to the window
chrome and the shared styling.

Three things were deliberately left alone:

- **Config filenames** (`AceDuels_MainGUI_Config_DefaultsV2.json` and the
  keybinds file) — renaming them would orphan everyone's saved settings.
- **The Discord link** — it's a real invite, so it stays as the header subtitle
  rather than being replaced with something invented.
- **Intro song filenames** — internal cache names, not user-visible.

`"SpideyHub"` was added to the startup cleanup list alongside the old GUI names,
so re-running the script still removes a previous instance instead of stacking
a second menu.

## Preview

`preview/ace-spiderverse-preview.html` is a browser mock built from the same
offsets and the same web/emblem maths, for checking the layout without loading
the game.
