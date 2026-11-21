# Interface theme (owner, 2026-11-20: the buttons, bars and boxes looked flat next to the world and the menu book)

**Done: the game uses the Gothic Pixel UI skin** (AbyssOwl; `ui/theme_gothic.tres`, set as `gui/theme/custom`). Five skins were tried (Dark Ages, Gothic, a wooden pack, a purple pack, a book pack);
the owner chose Gothic and the rest were removed. Credit to AbyssOwl is required for commercial use (`art/CREDITS.md`).

## How it is made

`python -I tools/build_ui_skin.py gothic <folder holding gothic_pixel_ui_free_v_1-0-2>` cuts the pack into `art/ui/skins/gothic/*.png` and writes `ui/theme_gothic.tres`: the game's own
`ui/theme.tres` (fonts, colors, type variations) with these replaced by textured styles:

- **Buttons** (`Choice`, `Back`, `OptionButton`): the ornate gold plaque; dropdowns and text fields use the plain gold frame, which leaves room for text.
- **Panels** (`Plate`, `Parchment`, `Chant`, `Hint`): the plain gold frame over the game's dark purple (parchment color for the controls sheet), with small corner brackets, drawn at 2x.
- **Stamina bar** (`HudBar`): the plain gold frame with a tight inset. The fill is the color of the school of the spell cast last (gold until the first one), eased in; unlimited stamina lays a pale white veil over it (`HudBar.sheen`, `Hud._color_of_last_spell`).
- **Wizard maker, stats screen, minimap**: the maker wears `Plate` (a little less padding); the stats screen's stand and chart tooltip and the minimap's frame use the stamina bar's gold frame (`HudBar` `frame` style), with the old flat look as the fallback.
- **Sliders**: a flat gold fill in a dark channel; **toggles**: the pack's ornate check buttons.

The pieces are drawn at 2x (one art pixel is two world pixels), as the rest of the UI art is. A new screen takes the look by using one of the type variations in `ui/theme.tres`; a panel built in code
with a `StyleBoxFlat` will not (that is how the pause sheet, settings plate, chant box and tutorial hints were moved onto the theme).

Pictures of every screen under a theme: `godot --path . --audio-driver Dummy tests/looks/ui_look.tscn -- theme=project out=DIR` (`theme=res://ui/other.tres` merges another theme over the project's).

## Not skinned yet

Enemy health bars (`scripts/creatures/mob.gd`), the Library's shelf ribbons, key caps. The F1 debug panel stays plain on purpose; the menu book and
the spellbook are their own art and are left alone.
