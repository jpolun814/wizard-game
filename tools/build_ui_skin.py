"""Cuts the Gothic Pixel UI pack into stretchable pieces and writes the game's theme from them: `art/ui/skins/gothic/*.png` and `ui/theme_gothic.tres`.

    python -I tools/build_ui_skin.py gothic <folder holding gothic_pixel_ui_free_v_1-0-2>

The theme is the game's own `ui/theme.tres` (fonts, colors, type variations) with the styles named in the wiring replaced by textured ones, so everything else
stays as it is; `gui/theme/custom` in project.godot points at the result. The download stays out of the repo; only the pieces cut for the game are kept in
`art/ui/skins/gothic/`. Credits: art/CREDITS.md (AbyssOwl: credit required).
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def laid_out(source, margin, width, height):
    """A frame at the size it will be used at: the four corners as drawn, each edge made of the artist's own edge pattern repeated (cut at the end, never stretched),
    and the middle one flat color. Used instead of the engine's tiling, which leaves seams, and instead of stretching, which smears the pattern."""
    m = margin
    out = Image.new("RGBA", (width, height))
    src_w, src_h = source.size
    out.paste(source.crop((0, 0, m, m)), (0, 0))
    out.paste(source.crop((src_w - m, 0, src_w, m)), (width - m, 0))
    out.paste(source.crop((0, src_h - m, m, src_h)), (0, height - m))
    out.paste(source.crop((src_w - m, src_h - m, src_w, src_h)), (width - m, height - m))
    top = source.crop((m, 0, src_w - m, m))
    bottom = source.crop((m, src_h - m, src_w - m, src_h))
    left = source.crop((0, m, m, src_h - m))
    right = source.crop((src_w - m, m, src_w, src_h - m))
    x = m
    while x < width - m:
        span = min(top.width, width - m - x)
        out.paste(top.crop((0, 0, span, m)), (x, 0))
        out.paste(bottom.crop((0, 0, span, m)), (x, height - m))
        x += span
    y = m
    while y < height - m:
        span = min(left.height, height - m - y)
        out.paste(left.crop((0, 0, m, span)), (0, y))
        out.paste(right.crop((0, 0, m, span)), (width - m, y))
        y += span
    middle = source.getpixel((src_w // 2, src_h // 2))
    out.paste(Image.new("RGBA", (width - 2 * m, height - 2 * m), middle), (m, m))
    return out


def textured(id_, res_path, margins, content=None, center=True, tile=False):
    left, top, right, bottom = margins
    lines = ['[sub_resource type="StyleBoxTexture" id="%s"]' % id_, 'texture = ExtResource("%s")' % res_path,
             "texture_margin_left = %d.0" % left, "texture_margin_top = %d.0" % top, "texture_margin_right = %d.0" % right, "texture_margin_bottom = %d.0" % bottom]
    if content is not None:
        for side, value in zip(("left", "top", "right", "bottom"), content):
            lines.append("content_margin_%s = %d.0" % (side, value))
    if not center:
        lines.append("draw_center = false")
    if tile:  # the border repeats along an edge, as the artist drew it, and is not stretched out of shape
        lines.append("axis_stretch_horizontal = 2")
        lines.append("axis_stretch_vertical = 2")
    return "\n".join(lines) + "\n"


def build(name, pieces, wiring):
    """`pieces` is {piece name: (image, (left, top, right, bottom) margins in the image's own pixels)}."""
    folder = os.path.join(ROOT, "art", "ui", "skins", name)
    os.makedirs(folder, exist_ok=True)
    margins = {}
    for piece, (image, edge) in pieces.items():
        image.save(os.path.join(folder, piece + ".png"))
        margins[piece] = edge
    base = open(os.path.join(ROOT, "ui", "theme.tres"), encoding="utf-8").read()
    ext, subs, assigns = [], [], []
    for k, piece in enumerate(pieces):
        ext.append('[ext_resource type="Texture2D" path="res://art/ui/skins/%s/%s.png" id="skin_%s"]' % (name, piece, piece))
    for style_id, spec in wiring["styles"].items():
        subs.append(textured(style_id, "skin_" + spec[0], margins[spec[0]], spec[1], tile=len(spec) > 2 and spec[2]))
    for line in wiring["assign"]:
        assigns.append(line)
    # the texture styles go in before [resource], the textures after the header, the assignments at its end (a later line wins, so they replace the flat ones)
    header_end = base.index("\n", base.index("[gd_resource")) + 1
    resource_at = base.index("[resource]")
    out = base[:header_end] + "\n".join(ext) + "\n" + base[header_end:resource_at] + "\n".join(subs) + "\n" + base[resource_at:].rstrip("\n") + "\n" + "\n".join(assigns) + "\n"
    # a replaced assignment must not appear twice: drop the base's line for every key assigned here
    keys = {line.split(" = ")[0] for line in assigns}
    kept = []
    seen_assignments = set()
    for line in reversed(out.split("\n")):  # (the last one is kept)
        key = line.split(" = ")[0]
        if key in keys and " = " in line:
            if key in seen_assignments:
                continue
            seen_assignments.add(key)
        kept.append(line)
    out = "\n".join(reversed(kept))
    open(os.path.join(ROOT, "ui", "theme_%s.tres" % name), "w", encoding="utf-8", newline="\n").write(out)
    print("wrote ui/theme_%s.tres and %d pieces in art/ui/skins/%s" % (name, len(pieces), name))


# --- Gothic Pixel UI (AbyssOwl): the gold set, whose frames are empty inside, filled here with the game's own dark ink ----------------------------------------
INK = (24, 13, 36, 255)        # the dark purple of the game's panels
PARCHMENT_INK = (216, 182, 144, 255)


def x2(image):
    return image.resize((image.width * 2, image.height * 2), Image.NEAREST)


def fill_inside(image, color):
    """Paints the empty space enclosed by a frame (flooding out from the middle). Leaves the picture alone if the frame is not closed."""
    from collections import deque
    out = image.copy()
    pixels = out.load()
    w, h = out.size
    seen = {(w // 2, h // 2)}
    queue = deque(seen)
    filled = []
    while queue:
        x, y = queue.popleft()
        if pixels[x, y][3] > 8:
            continue
        filled.append((x, y))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen:
                if (nx in (0, w - 1) or ny in (0, h - 1)) and pixels[nx, ny][3] <= 8:
                    print("  (a frame is not closed: left empty)")
                    return image
                seen.add((nx, ny))
                queue.append((nx, ny))
    for x, y in filled:
        pixels[x, y] = color
    return out


def tint(image, factor):
    """Brighter (above 1) or darker (below 1), without touching the see-through parts."""
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, int(r * factor)), min(255, int(g * factor)), min(255, int(b * factor)), a)
    return out


def retile(tile, fill, frame=1.0):
    """A framed tile with its brown middle swapped for `fill` and the gold frame brightened (above 1) or darkened (below 1)."""
    old = tile.getpixel((tile.width // 2, tile.height // 2))
    out = tile.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            if (r, g, b, a) == old:
                px[x, y] = fill
            elif frame != 1.0:
                px[x, y] = (min(255, int(r * frame)), min(255, int(g * frame)), min(255, int(b * frame)), a)
    return out


def with_corners(panel, corner, inset=0):
    """The pack's scrolled corner laid on each corner of a panel (one drawing, turned to fit all four)."""
    out = panel.copy()
    w, h = out.size
    cw, ch = corner.size
    flips = ((corner, (inset, inset)),
             (corner.transpose(Image.FLIP_LEFT_RIGHT), (w - cw - inset, inset)),
             (corner.transpose(Image.FLIP_TOP_BOTTOM), (inset, h - ch - inset)),
             (corner.transpose(Image.ROTATE_180), (w - cw - inset, h - ch - inset)))
    for image, at in flips:
        out.alpha_composite(image, at)
    return out


def tile_template(tile, m=4, g=8):
    """A frame tile cut down to its four corners and one clean stretch of each edge, so a panel made from it repeats only the clean part."""
    size = 2 * m + g
    out = Image.new("RGBA", (size, size))
    w, h = tile.size
    mid_x, mid_y = (w - g) // 2, (h - g) // 2
    out.paste(tile.crop((0, 0, m, m)), (0, 0))
    out.paste(tile.crop((w - m, 0, w, m)), (size - m, 0))
    out.paste(tile.crop((0, h - m, m, h)), (0, size - m))
    out.paste(tile.crop((w - m, h - m, w, h)), (size - m, size - m))
    out.paste(tile.crop((mid_x, 0, mid_x + g, m)), (m, 0))
    out.paste(tile.crop((mid_x, h - m, mid_x + g, h)), (m, size - m))
    out.paste(tile.crop((0, mid_y, m, mid_y + g)), (0, m))
    out.paste(tile.crop((w - m, mid_y, w, mid_y + g)), (size - m, m))
    out.paste(tile.crop((mid_x, mid_y, mid_x + g, mid_y + g)), (m, m))
    return out


def gothic(source):
    root = os.path.join(source, "gothic_pixel_ui_free_v_1-0-2")
    sheet = Image.open(os.path.join(root, "gothic_pixel_ui_free-v1-0-2.png")).convert("RGBA")
    split = os.path.join(root, "split_assets")
    frames = os.path.join(split, "frames and bars")
    strip = Image.open(os.path.join(split, "toggles and switches", "check_02_strip3.png")).convert("RGBA")
    box = lambda x0, y0, x1, y1: sheet.crop((x0, y0, x1 + 1, y1 + 1))
    tile32 = box(492, 329, 523, 360)      # the plain gold-framed tile: the pack's own nine-slice set
    corner = x2(box(222, 54, 230, 62))    # a plain L-shaped corner bracket (the scrolled corners were too busy)
    crest = x2(box(343, 15, 366, 27))     # a small flourish for the top of a bar
    plaque = box(417, 32, 472, 47)        # the ornate plaque: scrolled ends, two thin rails
    DEEP = (16, 9, 24, 255)
    INK2 = (36, 22, 52, 255)
    HOVER = (66, 42, 92, 255)
    base = fill_inside(plaque, INK2)

    def bar_piece(fill, frame):
        return x2(retile(base, fill, frame))

    template = tile_template(tile32)

    def panel(fill, size, ornaments=True):
        body = laid_out(retile(template, fill, 1.4), 4, size[0] // 2, size[1] // 2)
        return with_corners(x2(body), corner, inset=6) if ornaments else x2(body)

    plate = (14, 14, 14, 14)
    pieces = {
        "button": (bar_piece(INK2, 1.35), (28, 10, 28, 10)),
        "button_hover": (bar_piece(HOVER, 1.8), (28, 10, 28, 10)),
        "button_pressed": (bar_piece(DEEP, 1.1), (28, 10, 28, 10)),
        "field": (x2(retile(template, (12, 7, 18, 255), 1.3)), (8, 8, 8, 8)),
        "dropdown": (x2(retile(template, INK2, 1.4)), (8, 8, 8, 8)),
        "dropdown_hover": (x2(retile(template, HOVER, 1.8)), (8, 8, 8, 8)),
        "bar_body": (x2(retile(template, (10, 6, 16, 255), 1.5)), (8, 8, 8, 8)),
        "panel_hint": (panel(INK2, (200, 116)), plate),
        "panel_plate": (panel(INK2, (510, 640)), plate),
        "parchment": (panel(PARCHMENT_INK, (510, 330)), plate),
        "panel_chant": (panel((22, 13, 14, 235), (620, 64), ornaments=False), (8, 8, 8, 8)),
        "grabber": (Image.open(os.path.join(frames, "slider_handle_01.png")).convert("RGBA"), (0, 0, 0, 0)),
        "check_off": (strip.crop((0, 0, 28, 28)), (0, 0, 0, 0)),
        "check_on": (strip.crop((56, 0, 84, 28)), (0, 0, 0, 0)),
    }
    pieces.update(plain_slider((200, 160, 56), (14, 8, 22), (224, 176, 64)))  # (a flat gold fill in a dark channel, no gradient)
    button = (34, 14, 34, 14)
    wiring = skin_wiring(button, (30, 28, 30, 28), (30, 30, 30, 30), (30, 28, 30, 28), (14, 8, 14, 8), (16, 6, 16, 6), 6)
    wiring["styles"]["sk_drop"] = ("dropdown", (16, 11, 16, 11))
    wiring["styles"]["sk_drop_hover"] = ("dropdown_hover", (16, 11, 16, 11))
    wiring["assign"] = [a for a in wiring["assign"] if not a.startswith("OptionButton/styles/")] + [
        'OptionButton/styles/normal = SubResource("sk_drop")', 'OptionButton/styles/hover = SubResource("sk_drop_hover")',
        'OptionButton/styles/pressed = SubResource("sk_drop_hover")', 'OptionButton/styles/focus = SubResource("sk_drop_hover")']
    build("gothic", pieces, wiring)


def solid(color, size=3):
    return Image.new("RGBA", (size, size), color)


def plain_slider(outline, back, fill):
    """A thin track and its fill, the way every one of these packs has none: small flat boxes in the pack's own colors."""
    track = Image.new("RGBA", (8, 6), outline + (255,))
    track.paste(Image.new("RGBA", (6, 4), back + (255,)), (1, 1))
    return {"slider_track": (x2(track), (4, 4, 4, 4)), "slider_fill": (solid(fill + (255,)), (1, 1, 1, 1))}


def skin_wiring(button, hint, plate, parchment, chant, field, bar_inset, crown=False, button_text=None):
    """The wiring every skin shares (styles named sk_*, pieces named as in the dictionaries above)."""
    assign = [
        'Choice/styles/normal = SubResource("sk_button")', 'Choice/styles/hover = SubResource("sk_button_hover")', 'Choice/styles/pressed = SubResource("sk_button_pressed")',
        'Choice/styles/focus = SubResource("sk_button_hover")', 'Choice/styles/disabled = SubResource("sk_button")',
        'Back/styles/normal = SubResource("sk_button")', 'Back/styles/hover = SubResource("sk_button_hover")', 'Back/styles/pressed = SubResource("sk_button_pressed")',
        'Back/styles/focus = SubResource("sk_button_hover")', 'Back/styles/disabled = SubResource("sk_button")',
        'Field/styles/normal = SubResource("sk_field")', 'Field/styles/focus = SubResource("sk_button_hover")',
        'Plate/styles/panel = SubResource("sk_plate")', 'Parchment/styles/panel = SubResource("sk_parchment")',
        'Chant/styles/panel = SubResource("sk_chant")', 'Hint/styles/panel = SubResource("sk_hint")',
        'HudBar/styles/frame = SubResource("sk_bar")', 'HudBar/constants/inset_x = %d' % (bar_inset[0] if isinstance(bar_inset, tuple) else bar_inset), 'HudBar/constants/inset_y = %d' % (bar_inset[1] if isinstance(bar_inset, tuple) else bar_inset),
        'HSlider/styles/slider = SubResource("sk_track")', 'HSlider/styles/grabber_area = SubResource("sk_fill")', 'HSlider/styles/grabber_area_highlight = SubResource("sk_fill")',
        'HSlider/icons/grabber = ExtResource("skin_grabber")', 'HSlider/icons/grabber_highlight = ExtResource("skin_grabber")', 'HSlider/icons/grabber_disabled = ExtResource("skin_grabber")',
        'CheckButton/icons/checked = ExtResource("skin_check_on")', 'CheckButton/icons/unchecked = ExtResource("skin_check_off")',
        'CheckButton/icons/checked_disabled = ExtResource("skin_check_off")', 'CheckButton/icons/unchecked_disabled = ExtResource("skin_check_off")',
        'CheckButton/icons/checked_mirrored = ExtResource("skin_check_on")', 'CheckButton/icons/unchecked_mirrored = ExtResource("skin_check_off")',
        'CheckButton/icons/checked_disabled_mirrored = ExtResource("skin_check_off")', 'CheckButton/icons/unchecked_disabled_mirrored = ExtResource("skin_check_off")',
        'OptionButton/styles/normal = SubResource("sk_button")', 'OptionButton/styles/hover = SubResource("sk_button_hover")', 'OptionButton/styles/pressed = SubResource("sk_button_pressed")',
        'OptionButton/styles/focus = SubResource("sk_button_hover")', 'OptionButton/constants/h_separation = 8',
    ]
    if button_text:  # a light button needs dark lettering: (resting, hovered, pressed) as "r, g, b"
        for kind in ("Choice", "Back", "OptionButton"):
            for key, rgb in zip(("font_color", "font_focus_color", "font_hover_color", "font_pressed_color"), (button_text[0], button_text[1], button_text[1], button_text[2])):
                assign.append("%s/colors/%s = Color(%s, 1)" % (kind, key, rgb))
    if crown:
        assign += ['HudBar/constants/crown_sink = %d' % crown, 'HudBar/icons/crown = ExtResource("skin_bar_crown")']
    return {
        "styles": {
            "sk_button": ("button", button), "sk_button_hover": ("button_hover", button), "sk_button_pressed": ("button_pressed", button),
            "sk_field": ("field", field), "sk_plate": ("panel_plate", plate), "sk_parchment": ("parchment", parchment),
            "sk_chant": ("panel_chant", chant), "sk_hint": ("panel_hint", hint), "sk_bar": ("bar_body", None),
            "sk_track": ("slider_track", None), "sk_fill": ("slider_fill", None),
        },
        "assign": assign,
    }


if __name__ == "__main__":
    pack, source = sys.argv[1], sys.argv[2]
    {"gothic": gothic}[pack](source)
