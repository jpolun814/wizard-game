# Interface theme plan (owner, 2026-11-20: the buttons, bars and boxes look flat next to the world and the menu book)

**Status (2026-11-20): both skins are built; the owner is choosing.** The game still starts with its own flat look. Try one with `python tools/ui_skin.py darkages` or `gothic` (`none` goes back), then play. Pictures of every screen under a theme: `godot --path . --audio-driver Dummy tests/looks/ui_look.tscn -- theme=res://ui/theme_gothic.tres out=DIR`. The pieces come from `python -I tools/build_ui_skin.py <pack> <folder of the download>` (the downloads are not kept in the repo).

**What was done:** the five code-built panels (pause controls sheet, settings plate, chant box, tutorial hint) are now theme styles (`Parchment`, `Plate`, `Chant`, `Hint` in `ui/theme.tres`, same look as before); `HudBar` draws a frame, inset and crown from the theme when it has them; each skin theme is `ui/theme.tres` with the buttons, field, panels, bar, slider, check toggles and dropdown replaced by textured ones. **Not skinned yet:** enemy health bars, the minimap frame, the stats screen, the Library's shelf ribbons, the likeness panel, key caps and the F1 debug panel; the menu and spellbook are untouched on purpose.

## What the interface is made of today

There is no project theme (`gui/theme` is not set). Each screen builds its own flat `StyleBoxFlat` boxes in code:

| Element | Where | Looks like now |
|---|---|---|
| Stamina bar | `scripts/ui/hud_bar.gd` (8 `draw_rect`) | flat cyan (gold in a world) rectangle with plain text |
| Pause screen: controls table, Settings, Quit to menu, Quit to desktop | `scripts/ui/hud.gd`, `Pause` node | beige box, flat dark buttons |
| Settings panel (slider, option button, buttons) | `scripts/screens/settings_panel.gd` | flat panel and controls |
| Library screen: shelves, Back and other buttons | `scripts/screens/library_screen.gd` | the shelves are art; the buttons are flat |
| Stats screen | `scripts/screens/stats_screen.gd` | 7 `draw_rect` boxes and a button |
| Chant box | `scripts/arena/ritual_input.gd` | flat panel, `LineEdit` |
| Tutorial key hints and text boxes | `scripts/arena/tutorial.gd`, `scripts/screens/key_cap.gd` | flat boxes, key caps |
| Likeness panel (the wizard maker) | `scripts/screens/likeness_panel.gd` | panels, 3 buttons, `draw_rect` |
| Minimap frame | `scripts/ui/minimap.gd` | plain rectangle |
| Enemy health bars | `scripts/creatures/mob.gd` | 2 flat rectangles |
| Debug panel (F1) | `scripts/ui/debug_panel.gd` | developer tool: leave it plain |
| Already themed: the menu book, the spellbook, the blackletter lettering | `scripts/screens/menu.gd`, `spellbook.gd`, `lettering.gd` | keep as they are |

## Candidate art (checked on the pages, 2026-11-20; previews not yet looked at)

| Pack | What it holds | Terms | Concern |
|---|---|---|---|
| **[Gothic Pixel UI](https://abyssowl.itch.io/gothic-pixel-ui)** by AbyssOwl (free version) | 60 sprites in 4 colors (Gold, Bronze, Stone, Wood): 8 frames and 8 tiling borders and corners, 2 bars with 3 fills, sliders, check boxes, radio buttons, toggles, 9 icons | commercial and non-commercial use; edit freely; **credit to AbyssOwl required for commercial projects**; no resale; not for AI training; **no generative AI** | no text button in the free pack (frames serve as buttons); redistribution in a public repo is not addressed |
| **[Dark Ages UI](https://hypnobius.itch.io/dark-ages-ui)** by Hypnobius | 25 assets, 32x32 tiles: 4 menu frame autotiles, normal and hovered buttons, scrollbars, a stat bar frame, flourishes, icons | commercial use free or paid; credit optional; **no generative AI** | **may not be redistributed in any form**, so the files cannot sit in a public repo; do not scale below 32 px |
| [Parchment GUI](https://opengameart.org/content/parchment-gui) (zwonky, OpenGameArt) | parchment buttons, slots, labels, 16x16 | CC0 (from a search result; the page itself would not load) | no health bar; may be too light for the dark game |

Passed over: Heyheythere's Pixel UI Fantasy Free (made with AI assistance), Seveneves' Dark RPG GUI Kit (AI-assisted graphics), Moon Tribe's pack (paid), Kenney's Fantasy UI Borders (not pixel art).

**Repository note:** both gothic packs forbid passing the files on. As with the CraftPix art (`art/CREDITS.md`), putting them in a public repo is the owner's call.

## How it would be built

1. Cut the chosen pack into stretchable frames (`StyleBoxTexture` with nine-slice margins), at whole-number scales (rule: one art pixel is one world pixel).
2. One `Theme` resource (`res://theme/game_theme.tres`) for `Button`, `Panel`, `PanelContainer`, `ProgressBar`, `HSlider`, `CheckBox`, `OptionButton`, `LineEdit`, `TooltipPanel`, set as `gui/theme/custom` in `project.godot`.
3. Remove the per-screen `StyleBoxFlat` blocks so every screen takes the theme.
4. Replace the stamina bar, enemy bars and minimap frame with the pack's bar and frame art (they are drawn, not controls).
5. Credit lines in `art/CREDITS.md`; screenshots of every screen before and after (`tools/look_compare.py`).
