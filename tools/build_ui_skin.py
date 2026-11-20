"""Cuts an interface art pack into stretchable pieces and writes a theme that uses them: `art/ui/skins/<name>/*.png` and `ui/theme_<name>.tres`.

    python -I tools/build_ui_skin.py darkages <folder holding DarkAgesUi_v1.0>
    python -I tools/build_ui_skin.py gothic <folder holding gothic_pixel_ui_free_v_1-0-2>

The theme is the game's own `ui/theme.tres` (fonts, colors, type variations) with the styles named in SKINS replaced by textured ones, so everything else stays
as it is. To try a skin, set `gui/theme/custom` in project.godot to its file; to go back, set it to `res://ui/theme.tres`. The downloads stay out of the repo
(their licences forbid passing the files on), and only the pieces cut for the game are kept in `art/ui/skins/`. Credits: art/CREDITS.md.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# --- Dark Ages UI (Hypnobius): one 384 x 352 sheet of 32-pixel tiles, used at its own size ------------------------------------------------------------------
# name -> (box in the sheet, nine-slice margins left, top, right, bottom, scale)
DARKAGES_PIECES = {
    "button": ((0, 96, 64, 128), (14, 10, 14, 8), 1),
    "button_hover": ((128, 96, 192, 128), (14, 10, 14, 8), 1),
    "button_pressed": ((64, 96, 128, 128), (14, 10, 14, 8), 1),
    "frame_gold": ((0, 0, 96, 96), (28, 28, 28, 28), 1),  # the pack's showpiece: gold, blue weave and scrolled corners
    "panel_dark": ((210, 18, 270, 78), (20, 20, 20, 20), 1),
    "panel_light": ((306, 18, 366, 78), (20, 20, 20, 20), 1),
    "parchment": ((96, 0, 192, 96), (14, 14, 14, 14), 1),
    "field": ((288, 96, 320, 128), (8, 10, 8, 8), 1),
    "bar_body": ((197, 142, 283, 150), (3, 3, 3, 2), 2),  # the frame of a bar, without the crown, drawn twice the size
    "bar_crown": ((233, 135, 249, 142), (0, 0, 0, 0), 2),
    "slider_track": ((102, 141, 186, 148), (8, 2, 8, 2), 2),
    "slider_fill": ((296, 144, 378, 148), (2, 1, 2, 1), 2),
    "diamond_on": ((10, 266, 23, 278), (0, 0, 0, 0), 2),
    "diamond_off": ((10, 298, 23, 310), (0, 0, 0, 0), 2),
}


# name -> (piece it is made from, (width, height) it is made at): the sizes the panels are shown at in the game
LAID_OUT = {"frame_hint": ("frame_gold", (200, 116)), "frame_plate": ("frame_gold", (510, 640)), "frame_chant": ("panel_dark", (620, 64))}


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


def cut(sheet, name, pieces):
    box, margins, scale = pieces[name]
    image = sheet.crop(box)
    if scale != 1:
        image = image.resize((image.width * scale, image.height * scale), Image.NEAREST)
    return image, tuple(m * scale for m in margins)


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


def darkages(source):
    sheet = Image.open(os.path.join(source, "DarkAgesUi_v1.0", "32x32-Tilesheet.png")).convert("RGBA")
    button = (20, 12, 20, 10)
    wiring = {
        "styles": {
            "sk_button": ("button", button), "sk_button_hover": ("button_hover", button), "sk_button_pressed": ("button_pressed", button),
            "sk_field": ("field", (12, 8, 12, 8)),
            "sk_plate": ("frame_plate", (36, 36, 36, 36)), "sk_parchment": ("parchment", (20, 20, 20, 20)),
            "sk_chant": ("frame_chant", (20, 14, 20, 14)), "sk_hint": ("frame_hint", (32, 30, 32, 30)),
            "sk_bar": ("bar_body", None),
            "sk_track": ("slider_track", None), "sk_fill": ("slider_fill", None),
        },
        "assign": [
            'Choice/styles/normal = SubResource("sk_button")', 'Choice/styles/hover = SubResource("sk_button_hover")', 'Choice/styles/pressed = SubResource("sk_button_pressed")',
            'Choice/styles/focus = SubResource("sk_button_hover")', 'Choice/styles/disabled = SubResource("sk_button")',
            'Back/styles/normal = SubResource("sk_button")', 'Back/styles/hover = SubResource("sk_button_hover")', 'Back/styles/pressed = SubResource("sk_button_pressed")',
            'Back/styles/focus = SubResource("sk_button_hover")', 'Back/styles/disabled = SubResource("sk_button")',
            'Field/styles/normal = SubResource("sk_field")', 'Field/styles/focus = SubResource("sk_button_hover")',
            'Plate/styles/panel = SubResource("sk_plate")', 'Parchment/styles/panel = SubResource("sk_parchment")',
            'Chant/styles/panel = SubResource("sk_chant")', 'Hint/styles/panel = SubResource("sk_hint")',
            'HudBar/styles/frame = SubResource("sk_bar")', 'HudBar/constants/inset_x = 6', 'HudBar/constants/inset_y = 4', 'HudBar/constants/crown_sink = 4',
            'HudBar/icons/crown = ExtResource("skin_bar_crown")',
            'HSlider/styles/slider = SubResource("sk_track")', 'HSlider/styles/grabber_area = SubResource("sk_fill")', 'HSlider/styles/grabber_area_highlight = SubResource("sk_fill")',
            'HSlider/icons/grabber = ExtResource("skin_diamond_on")', 'HSlider/icons/grabber_highlight = ExtResource("skin_diamond_on")', 'HSlider/icons/grabber_disabled = ExtResource("skin_diamond_off")',
            'CheckButton/icons/checked = ExtResource("skin_diamond_on")', 'CheckButton/icons/unchecked = ExtResource("skin_diamond_off")',
            'CheckButton/icons/checked_disabled = ExtResource("skin_diamond_off")', 'CheckButton/icons/unchecked_disabled = ExtResource("skin_diamond_off")',
            'CheckButton/icons/checked_mirrored = ExtResource("skin_diamond_on")', 'CheckButton/icons/unchecked_mirrored = ExtResource("skin_diamond_off")',
            'CheckButton/icons/checked_disabled_mirrored = ExtResource("skin_diamond_off")', 'CheckButton/icons/unchecked_disabled_mirrored = ExtResource("skin_diamond_off")',
            'OptionButton/styles/normal = SubResource("sk_button")', 'OptionButton/styles/hover = SubResource("sk_button_hover")', 'OptionButton/styles/pressed = SubResource("sk_button_pressed")',
            'OptionButton/styles/focus = SubResource("sk_button_hover")', 'OptionButton/constants/h_separation = 8',
        ],
    }
    pieces = {piece: cut(sheet, piece, DARKAGES_PIECES) for piece in DARKAGES_PIECES}
    for name, (source, size) in LAID_OUT.items():  # (a frame cut to the size it is shown at)
        image, edge = pieces[source]
        pieces[name] = (laid_out(image, edge[0], size[0], size[1]), edge)
    build("darkages", pieces, wiring)


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


def gothic(source):
    root = os.path.join(source, "gothic_pixel_ui_free_v_1-0-2")
    sheet = Image.open(os.path.join(root, "gothic_pixel_ui_free-v1-0-2.png")).convert("RGBA").crop((0, 0, 650, 400))
    split = os.path.join(root, "split_assets")
    frames = os.path.join(split, "frames and bars")
    strip = Image.open(os.path.join(split, "toggles and switches", "check_02_strip3.png")).convert("RGBA")
    box = lambda x0, y0, x1, y1: sheet.crop((x0, y0, x1, y1))
    pill = box(472, 72, 526, 92)          # the ornate button, dark inside
    square = box(158, 17, 202, 61)        # the square frame
    rounded = box(106, 17, 154, 65)       # the rounded frame
    pieces = {
        "button": (x2(pill), (20, 12, 20, 12)),
        "button_hover": (x2(tint(pill, 1.35)), (20, 12, 20, 12)),
        "button_pressed": (x2(tint(pill, 0.7)), (20, 12, 20, 12)),
        "field": (x2(box(407, 70, 467, 94)), (24, 14, 24, 14)),
        "panel_plate": (x2(fill_inside(square, INK)), (30, 30, 30, 30)),
        "panel_hint": (x2(fill_inside(rounded, INK)), (32, 32, 32, 32)),
        "panel_chant": (x2(fill_inside(square, (30, 20, 14, 235))), (30, 30, 30, 30)),
        "parchment": (x2(fill_inside(square, PARCHMENT_INK)), (30, 30, 30, 30)),
        "bar_body": (x2(box(418, 15, 472, 31)), (16, 10, 16, 10)),
        "slider_track": (Image.open(os.path.join(frames, "24px_border_03.png")).convert("RGBA"), (6, 4, 6, 4)),
        "slider_fill": (Image.open(os.path.join(frames, "bar_fill_01.png")).convert("RGBA"), (1, 1, 1, 1)),
        "grabber": (Image.open(os.path.join(frames, "slider_handle_01.png")).convert("RGBA"), (0, 0, 0, 0)),
        "check_off": (strip.crop((0, 0, 28, 28)), (0, 0, 0, 0)),
        "check_on": (strip.crop((56, 0, 84, 28)), (0, 0, 0, 0)),
    }
    button = (24, 8, 24, 8)
    wiring = {
        "styles": {
            "sk_button": ("button", button), "sk_button_hover": ("button_hover", button), "sk_button_pressed": ("button_pressed", button),
            "sk_field": ("field", (16, 8, 16, 8)),
            "sk_plate": ("panel_plate", (26, 26, 26, 26)), "sk_parchment": ("parchment", (26, 26, 26, 26)),
            "sk_chant": ("panel_chant", (22, 22, 22, 22)), "sk_hint": ("panel_hint", (26, 26, 26, 26)),
            "sk_bar": ("bar_body", None),
            "sk_track": ("slider_track", None), "sk_fill": ("slider_fill", None),
        },
        "assign": [
            'Choice/styles/normal = SubResource("sk_button")', 'Choice/styles/hover = SubResource("sk_button_hover")', 'Choice/styles/pressed = SubResource("sk_button_pressed")',
            'Choice/styles/focus = SubResource("sk_button_hover")', 'Choice/styles/disabled = SubResource("sk_button")',
            'Back/styles/normal = SubResource("sk_button")', 'Back/styles/hover = SubResource("sk_button_hover")', 'Back/styles/pressed = SubResource("sk_button_pressed")',
            'Back/styles/focus = SubResource("sk_button_hover")', 'Back/styles/disabled = SubResource("sk_button")',
            'Field/styles/normal = SubResource("sk_field")', 'Field/styles/focus = SubResource("sk_button_hover")',
            'Plate/styles/panel = SubResource("sk_plate")', 'Parchment/styles/panel = SubResource("sk_parchment")',
            'Chant/styles/panel = SubResource("sk_chant")', 'Hint/styles/panel = SubResource("sk_hint")',
            'HudBar/styles/frame = SubResource("sk_bar")', 'HudBar/constants/inset_x = 12', 'HudBar/constants/inset_y = 8',
            'HSlider/styles/slider = SubResource("sk_track")', 'HSlider/styles/grabber_area = SubResource("sk_fill")', 'HSlider/styles/grabber_area_highlight = SubResource("sk_fill")',
            'HSlider/icons/grabber = ExtResource("skin_grabber")', 'HSlider/icons/grabber_highlight = ExtResource("skin_grabber")', 'HSlider/icons/grabber_disabled = ExtResource("skin_grabber")',
            'CheckButton/icons/checked = ExtResource("skin_check_on")', 'CheckButton/icons/unchecked = ExtResource("skin_check_off")',
            'CheckButton/icons/checked_disabled = ExtResource("skin_check_off")', 'CheckButton/icons/unchecked_disabled = ExtResource("skin_check_off")',
            'CheckButton/icons/checked_mirrored = ExtResource("skin_check_on")', 'CheckButton/icons/unchecked_mirrored = ExtResource("skin_check_off")',
            'CheckButton/icons/checked_disabled_mirrored = ExtResource("skin_check_off")', 'CheckButton/icons/unchecked_disabled_mirrored = ExtResource("skin_check_off")',
            'OptionButton/styles/normal = SubResource("sk_button")', 'OptionButton/styles/hover = SubResource("sk_button_hover")', 'OptionButton/styles/pressed = SubResource("sk_button_pressed")',
            'OptionButton/styles/focus = SubResource("sk_button_hover")', 'OptionButton/constants/h_separation = 8',
        ],
    }
    build("gothic", pieces, wiring)


if __name__ == "__main__":
    pack, source = sys.argv[1], sys.argv[2]
    {"darkages": darkages, "gothic": gothic}[pack](source)
