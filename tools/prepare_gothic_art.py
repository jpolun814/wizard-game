"""Builds the game's pixel art from the downloaded packs (all CC0, see art/CREDITS.md).

    python tools/prepare_gothic_art.py <downloads dir>

The downloads dir holds the unzipped packs, each in its own folder:
    wizard-pack/                LuizMelo, Wizard Pack                  (the player)
    evil_wizard_2/              LuizMelo, Evil Wizard 2                (the dark wizard)
    monsters-creatures-fantasy/ LuizMelo, Monsters Creatures Fantasy   (the enemies)
    x_gothicvania-cemetery-files, x_swamp, x_church, x_town            ansimuz, GothicVania packs (levels)
    x_spells, x_starsteel, x_lightning, x_explosions, x_fire          spell effects
    x_freefx                    CodeManu, Free Pixel Effects Pack     (vortex, rings, ice, wind, bubbles)
    x_portals                   LetargicDev, Portals                  (the portal)
    icicles                     Kamioo, Pixel Icicles                 (rock spikes)
    x_clouds                    DustDFG, Pixel Art Clouds             (storm and snow clouds)
    x_tinydungeon               Kenney, Tiny Dungeon                  (the wand and staff on the ground)
    books/foxel                 Foxel Games, Pixel Art Book           (the spellbook)
Some effects are recoloured here to their school's colours (a hue turn, or a ramp from dark to light).

Characters are cut out of their sprite sheets into single frames that all share one canvas, with the character's
feet on the canvas's bottom edge (its middle, for a flyer) and its body centred left to right, so flipping a frame
to face the other way never shifts the character. The tiles are packed into the 16-piece atlas layout terrain.gd
reads. Everything else is copied at its own size.
"""

import colorsys
import glob
import math
import os
import random
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name: (sheet folder, frame width, frame height, flyer, {animation: (file, frames to keep or None)})
LUIZ_MONSTERS = "monsters-creatures-fantasy/Monsters_Creatures_Fantasy_x/Monsters_Creatures_Fantasy/"
LUIZ_MONSTERS_13 = "monsters-creatures-fantasy/Monster_Creatures_Fantasy(Version 1.3)_x/Monster_Creatures_Fantasy(Version 1.3)/"
CHARACTERS = {
    "wizard": ("wizard-pack/Wizard Pack_x/Wizard Pack/", 231, 190, False, {
        "idle": "Idle.png", "run": "Run.png", "jump": "Jump.png", "fall": "Fall.png",
        "cast": "Attack1.png", "release": "Attack2.png", "hit": "Hit.png", "death": "Death.png"}),
    "dark_wizard": ("evil_wizard_2/EVil Wizard 2_x/EVil Wizard 2/Sprites/", 250, 250, False, {
        "idle": "Idle.png", "run": "Run.png", "jump": "Jump.png", "fall": "Fall.png",
        "cast": "Attack1.png", "release": "Attack2.png", "hit": "Take hit.png", "death": "Death.png"}),
    "skeleton": (LUIZ_MONSTERS + "Skeleton/", 150, 150, False, {
        "idle": "Idle.png", "walk": "Walk.png", "attack": "Attack.png", "hit": "Take Hit.png", "death": "Death.png"}),
    "goblin": (LUIZ_MONSTERS + "Goblin/", 150, 150, False, {
        "idle": "Idle.png", "walk": "Run.png", "attack": LUIZ_MONSTERS_13 + "Goblin/Attack3.png",
        "hit": "Take Hit.png", "death": "Death.png"}),
    "eye": (LUIZ_MONSTERS + "Flying eye/", 150, 150, True, {
        "idle": "Flight.png", "attack": "Attack.png", "hit": "Take Hit.png", "death": "Death.png"}),
}
MOBS = ["skeleton", "goblin", "eye"]
HEROES = ["wizard", "dark_wizard"]

CEMETERY = "x_gothicvania-cemetery-files/gothicvania-cemetery-files/Assets/Environment/"
SWAMP = "x_swamp/Gothicvania Swamp files/Evironment/"
CHURCH = "x_church/gothicvania church files/ENVIRONMENT/"
TOWN = "x_town/GothicVania-town-files/PNG/environment/"

# Each tileset is described by the 16 px tiles that play each role: the corners, edges and middle of a block of
# ground, its bottom, and the plain deep earth under it. A cell is (x, y) in the tileset, or ("fill", (x, y)) for a
# tile flooded with that cell's most common colour. Each 32 px piece of the game's atlas is built from four of them,
# so the ground has the same pixel size as the characters standing on it.
PIECES = ["top_left", "top", "top_right", "single",
          "left", "center", "right", "ledge_left",
          "bottom_left", "bottom", "bottom_right", "ledge_middle",
          "column_top", "column_middle", "column_bottom", "ledge_right",
          "deep_left", "deep", "deep_right", "deep_single"]
# piece -> its four quarters, top-left, top-right, bottom-left, bottom-right, as role names.
LAYOUT = {
    "top_left": ("TL", "T", "L", "C"), "top": ("T", "T", "C", "C"), "top_right": ("T", "TR", "C", "R"),
    "single": ("TL", "TR", "BL", "BR"),
    "left": ("L", "C", "L", "D"), "center": ("C", "C", "D", "D"), "right": ("C", "R", "D", "R"),
    "ledge_left": ("TL", "T", "BL", "B"),
    "bottom_left": ("L", "D", "BL", "B"), "bottom": ("D", "D", "B", "B"), "bottom_right": ("D", "R", "B", "BR"),
    "ledge_middle": ("T", "T", "B", "B"),
    "column_top": ("TL", "TR", "L", "R"), "column_middle": ("L", "R", "L", "R"), "column_bottom": ("L", "R", "BL", "BR"),
    "ledge_right": ("T", "TR", "B", "BR"),
    "deep_left": ("L", "D", "L", "D"), "deep": ("D", "D", "D", "D"), "deep_right": ("D", "R", "D", "R"),
    "deep_single": ("L", "R", "L", "R"),
}
TILESETS = {
    "cemetery": {"src": CEMETERY + "tileset.png", "roles": {
        "TL": (1, 4), "T": (5, 4), "TR": (2, 4), "L": (1, 5), "C": (5, 5), "R": (2, 5),
        "BL": (1, 6), "B": ("fill", (1, 6)), "BR": (2, 6), "D": ("fill", (1, 6))}},
    "swamp": {"src": SWAMP + "tileset.png", "roles": {
        "TL": (0, 0), "T": (3, 0), "TR": (20, 0), "L": (0, 1), "C": (3, 1), "R": (20, 1),
        "BL": (0, 3), "B": (3, 3), "BR": (20, 3), "D": (3, 3)}},
    "church": {"src": CHURCH + "tileset.png", "roles": {
        "TL": (0, 10), "T": (1, 10), "TR": (2, 10), "L": (0, 11), "C": (1, 11), "R": (2, 11),
        "BL": (0, 12), "B": (1, 12), "BR": (2, 12), "D": ("fill", (1, 12))}},
    # Cut stone from the church for every pillar, mound and Stone Wall: each piece is one block of four stones.
    "stone": {"src": CHURCH + "tileset.png", "roles": {
        "TL": (4, 7), "T": (4, 7), "TR": (5, 7), "L": (4, 8), "C": (4, 8), "R": (5, 8),
        "BL": (4, 8), "B": (4, 8), "BR": (5, 8), "D": (5, 8)}},
}
ATLAS_TILE = 64
ATLAS_PAD = 4

# Props: name -> source file, copied at their own pixel size.
PROPS = {
    "grave_1": CEMETERY + "sliced-objects/stone-1.png", "grave_2": CEMETERY + "sliced-objects/stone-2.png",
    "grave_3": CEMETERY + "sliced-objects/stone-3.png", "grave_4": CEMETERY + "sliced-objects/stone-4.png",
    "dead_tree_1": CEMETERY + "sliced-objects/tree-1.png", "dead_tree_2": CEMETERY + "sliced-objects/tree-2.png",
    "dead_tree_3": CEMETERY + "sliced-objects/tree-3.png", "statue": CEMETERY + "sliced-objects/statue.png",
    "bush_large": CEMETERY + "sliced-objects/bush-large.png", "bush_small": CEMETERY + "sliced-objects/bush-small.png",
    "church_column": CHURCH + "column.png",
    "crate": TOWN + "props-sliced/crate.png", "barrel": TOWN + "props-sliced/barrel.png",
    "street_lamp": TOWN + "props-sliced/street-lamp.png",
    "plank": TOWN + "layers/sliced-tileset/top-wood.png",
    "plank_legs": TOWN + "layers/sliced-tileset/wood-legs.png",
}
# Pieces cut out of sheets: name -> (file, box).
PROP_CUTS = {
    "swamp_grass": (SWAMP + "tileset.png", (32, 72, 64, 112)),
    "swamp_vine": (SWAMP + "tileset.png", (88, 80, 144, 112)),
    "swamp_fern": (SWAMP + "tileset.png", (168, 72, 208, 112)),
    "balustrade": (CHURCH + "tileset.png", (192, 96, 272, 144)),
    "mound": (CEMETERY + "tileset.png", (280, 56, 436, 144)),
}

# Backdrop layers per place, farthest first: name -> file (and a crop box for sheets holding several pictures).
BACKDROPS = {
    "cemetery": [("sky", CEMETERY + "background.png", None), ("far", CEMETERY + "mountains.png", None),
                 ("near", CEMETERY + "graveyard.png", None)],
    "swamp": [("sky", SWAMP + "background.png", None), ("far", SWAMP + "mid-layer-01.png", None),
              ("mid", SWAMP + "mid-layer-02.png", None), ("near", SWAMP + "trees.png", None)],
    "church": [("far", CHURCH + "backgrounds.png", (0, 0, 160, 192)), ("mid", CHURCH + "backgrounds.png", (176, 0, 304, 192)),
               ("near", CHURCH + "backgrounds.png", (320, 0, 448, 192)), ("gargoyle", CHURCH + "backgrounds.png", (464, 0, 544, 192))],
}

# Effects, saved as one horizontal strip each: name -> list of frame files, or (sheet, frame width).
FX = {
    "fireball": ("x_starsteel/Fireball{}.png", 9),
    "icespear": ("x_starsteel/Icespear{}.png", 6),
    "thunder_orb": ("x_starsteel/Thundersphere{}.png", 8),
    "lightning": ("x_lightning/Lighting Strike {}.png", 7),
    "enemy_death": ("x_church/gothicvania church files/SPRITES/fx/enemy-death/enemy-death-sprites/enemy-death{}.png", 9),
}
FX_SHEETS = {
    "blast_small": ("x_explosions/explosions-pack/spritesheets/explosion-2.png", 64),
    "blast_fire": ("x_explosions/explosions-pack/spritesheets/explosion-3.png", 80),
    "blast_dust": ("x_explosions/explosions-pack/spritesheets/explosion-4.png", 128),
    "blast_big": ("x_explosions/explosions-pack/spritesheets/explosion-5.png", 192),
    "blast_ring": ("x_explosions/explosions-pack/spritesheets/explosion-1.png", 32),
    "dark_orb": ("x_spells/Pixelart Spells/PNG Files/Darkness Orb.png", 16),
    "dark_bolt": ("x_spells/Pixelart Spells/PNG Files/Darkness Bolt.png", 16),
    "magic_bolt": ("x_spells/Pixelart Spells/PNG Files/Arcane Bolt.png", 16),
    "ice_lance": ("x_spells/Pixelart Spells/PNG Files/Ice Lance.png", 16),
    "rock": ("x_spells/Pixelart Spells/PNG Files/Rock Sling.png", 16),
    "eye_shot": (LUIZ_MONSTERS_13 + "Flying eye/projectile_sprite.png", 48),
    "goblin_bomb": (LUIZ_MONSTERS_13 + "Goblin/Bomb_sprite.png", 100),
    "shield": ("x_spells/Pixelart Spells/PNG Files/Pixelart Shield.png", 48),
    "wind_bolt": ("x_spells/Pixelart Spells/PNG Files/Wind Bolt.png", 16),
}
# Effects laid out in a grid and recoloured: name -> (sheet, frame width, frame height, and a recolouring: None,
# ("hue", degrees), or ("ramp", dark colour, light colour)). Empty cells are skipped.
FORCE_RAMP = ("ramp", (40, 14, 70), (236, 214, 255))
FX_RECOLOURED = {
    "vortex": ("x_freefx/13_vortex_spritesheet.png", 100, 100, FORCE_RAMP),
    "ring": ("x_freefx/10_weaponhit_spritesheet.png", 100, 100, None),
    "slash": ("x_freefx/14_phantom_spritesheet.png", 100, 100, FORCE_RAMP),
    "ice_burst": ("x_freefx/12_nebula_spritesheet.png", 100, 100, None),
    "freeze": ("x_freefx/19_freezing_spritesheet.png", 100, 100, None),
    "wind": ("x_freefx/7_firespin_spritesheet.png", 100, 100, ("ramp", (70, 84, 104), (240, 248, 255))),
    "bubbles": ("x_freefx/20_magicbubbles_spritesheet.png", 100, 100, ("ramp", (60, 40, 18), (214, 178, 112))),
    "portal_open": ("x_portals/portalRings1.png", 32, 32, ("hue", 150)),
    "portal_loop": ("x_portals/portalRings2.png", 32, 32, ("hue", 150)),
}
# Effects laid out in a grid, read left to right and top to bottom: name -> (sheet, frame width, frame height).
FX_GRIDS = {
    "flame": ("x_fire/fire5_64_0.png", 64, 64),
    "flame_blue": ("x_fire/fire6_64_0.png", 64, 64),
}


def recolour(image, how):
    """A hue turn (which keeps greys grey, so stone stays stone), or a ramp mapping dark to light onto two colours."""
    if how is None:
        return image
    out = image.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if how[0] == "hue":
                h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                r2, g2, b2 = colorsys.hsv_to_rgb((h + how[1] / 360.0) % 1.0, sat, v)
                px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
            else:
                k = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                lo, hi = how[1], how[2]
                px[x, y] = tuple(int(lo[i] + (hi[i] - lo[i]) * k) for i in range(3)) + (a,)
    return out


def grid_frames(sheet, fw, fh):
    cells = [sheet.crop((x, y, x + fw, y + fh)) for y in range(0, sheet.height - fh + 1, fh)
             for x in range(0, sheet.width - fw + 1, fw)]
    return [c for c in cells if alpha_box(c)]


def key_out(image):
    """Makes a picture's flat background colour (its top-left pixel) transparent."""
    out = image.copy()
    px = out.load()
    bg = px[0, 0]
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][:3] == bg[:3]:
                px[x, y] = (0, 0, 0, 0)
    return out


def alpha_box(image):
    return image.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()


def frames_of(sheet, fw, fh):
    return [sheet.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(sheet.width // fw)]


def body_column(frames, flyer):
    """Where the character's body is left to right in its frames, and its feet (or middle) top to bottom."""
    xs, total, bottom, top = 0.0, 0.0, 0, 10 ** 6
    for f in frames:
        box = alpha_box(f)
        if not box:
            continue
        bottom = max(bottom, box[3])
        top = min(top, box[1])
        a = f.getchannel("A").load()
        # The legs and lower body, not a staff held out to the side: weight columns by how many solid pixels they
        # have in the lower half of the character.
        for y in range((box[1] + box[3]) // 2, box[3]):
            for x in range(box[0], box[2]):
                if a[x, y] > 24:
                    xs += x
                    total += 1
    centre_x = xs / total
    anchor_y = (top + bottom) / 2.0 if flyer else bottom
    return centre_x, anchor_y


def body_box(frames, centre_x, anchor_y):
    """The body's box measured from the anchor: columns that are mostly solid through the idle frames, so a staff
    or a weapon held out doesn't widen the hitbox."""
    f = frames[0]
    box = alpha_box(f)
    a = f.getchannel("A").load()
    counts = {x: sum(1 for y in range(box[1], box[3]) if a[x, y] > 24) for x in range(box[0], box[2])}
    tallest = max(counts.values())
    cols = [x for x, c in counts.items() if c >= tallest * 0.45]
    left, right = min(cols), max(cols) + 1
    return (left - centre_x, box[1] - anchor_y, right - left, box[3] - box[1])


def prepare_character(name, downloads):
    folder, fw, fh, flyer, anims = CHARACTERS[name]
    sheets = {}
    for anim, file in anims.items():
        path = file if "/" in file else folder + file
        sheets[anim] = frames_of(Image.open(os.path.join(downloads, path)).convert("RGBA"), fw, fh)
    centre_x, anchor_y = body_column(sheets["idle"], flyer)
    # The canvas holds every frame of every animation, symmetric about the body's middle.
    reach_x, up, down = 0.0, 0.0, 0.0
    for frames in sheets.values():
        for f in frames:
            box = alpha_box(f)
            if box:
                reach_x = max(reach_x, centre_x - box[0], box[2] - centre_x)
                up = max(up, anchor_y - box[1])
                down = max(down, box[3] - anchor_y)
    half_w = int(reach_x + 2)
    top = int(up + 2)
    bottom = int(down + 2) if flyer else 0
    if flyer:
        top = bottom = max(top, bottom)
    out_dir = os.path.join(ROOT, "art", "mobs" if name in MOBS else "chars", name)
    shutil.rmtree(out_dir, ignore_errors=True)
    os.makedirs(out_dir)
    for anim, frames in sheets.items():
        for i, f in enumerate(frames):
            canvas = Image.new("RGBA", (half_w * 2, top + bottom))
            canvas.paste(f, (int(round(half_w - centre_x)), int(round(top - anchor_y))))
            canvas.save(os.path.join(out_dir, "%s_%d.png" % (anim, i)), optimize=True)
    body = body_box(sheets["idle"], centre_x, anchor_y)
    return {"size": (half_w * 2, top + bottom), "body": body, "flyer": flyer}


def build_atlas(spec, downloads, dst):
    src = Image.open(os.path.join(downloads, spec["src"])).convert("RGBA")

    def role(name):
        how = spec["roles"][name]
        if how[0] == "fill":
            c = how[1]
            cell = src.crop((c[0] * 16, c[1] * 16, c[0] * 16 + 16, c[1] * 16 + 16))
            colour = max((n for n in cell.getcolors(256) if n[1][3] > 200), key=lambda n: n[0])[1]
            return Image.new("RGBA", (16, 16), colour)
        return src.crop((how[0] * 16, how[1] * 16, how[0] * 16 + 16, how[1] * 16 + 16))

    cell_size = ATLAS_TILE + ATLAS_PAD * 2
    atlas = Image.new("RGBA", (cell_size * 4, cell_size * 5))
    for i, piece in enumerate(PIECES):
        quarters = LAYOUT[piece]
        t = Image.new("RGBA", (32, 32))
        for q, name in enumerate(quarters):
            t.alpha_composite(role(name), ((q % 2) * 16, (q // 2) * 16))
        t = t.resize((ATLAS_TILE, ATLAS_TILE), Image.NEAREST)
        # Extrude the edges into the padding, so neighbouring tiles never bleed in.
        padded = t.resize((ATLAS_TILE + ATLAS_PAD * 2, ATLAS_TILE + ATLAS_PAD * 2), Image.NEAREST)
        padded.paste(t, (ATLAS_PAD, ATLAS_PAD))
        atlas.paste(padded, ((i % 4) * cell_size, (i // 4) * cell_size))
    atlas.save(dst, optimize=True)


# --- The wizard holding a wand -----------------------------------------------------------------------------------
# The Wizard Pack only draws its wizard with a staff. For the wand, each frame's staff is cut down to the short
# piece in the wizard's hand, with the crystal moved to its tip: the staff's wood, outline and crystal have colours
# of their own, so they can be found and erased.
POLE = {(61, 35, 16)}
CRYSTAL = {(51, 218, 255), (193, 255, 250)}
DARK = {(30, 16, 6), (54, 30, 13), (72, 40, 17)}  # the staff's outline and shading, also used elsewhere
SKIN = {(187, 143, 130), (154, 105, 91), (165, 113, 98)}
KEEP = 9      # pole this close to the hand stays: the wand
REACH = 3.0   # pixels this close to the staff's line are part of the staff


def wandify(im):
    im = im.copy()
    px = im.load()
    w, h = im.size
    solid = lambda p: 0 <= p[0] < w and 0 <= p[1] < h and px[p][3] > 0
    pole = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 0 and px[x, y][:3] in POLE]
    crystal = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 0 and px[x, y][:3] in CRYSTAL]
    if len(pole) < 6:
        return im, False
    # The staff's line: the straight line through the most pole pixels (so a stray pixel of the same colour
    # elsewhere doesn't tilt it).
    rnd = random.Random(1)
    best = None
    for _ in range(300):
        a, b = rnd.sample(pole, 2)
        if a == b:
            continue
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        ux, uy = math.cos(ang), math.sin(ang)
        inl = [p for p in pole if abs(-(p[0] - a[0]) * uy + (p[1] - a[1]) * ux) <= 1.5]
        if best is None or len(inl) > len(best[0]):
            best = (inl, ang)
    inliers, angle = best
    mx = sum(p[0] for p in inliers) / len(inliers)
    my = sum(p[1] for p in inliers) / len(inliers)
    # Refine the angle by least squares over the inliers.
    sxx = sum((p[0] - mx) ** 2 for p in inliers)
    syy = sum((p[1] - my) ** 2 for p in inliers)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in inliers)
    angle = 0.5 * math.atan2(2 * sxy, sxx - syy)
    pole = inliers
    dx, dy = math.cos(angle), math.sin(angle)
    along = lambda p: (p[0] - mx) * dx + (p[1] - my) * dy
    across = lambda p: abs(-(p[0] - mx) * dy + (p[1] - my) * dx)
    lo = min(along(p) for p in pole) - 2
    hi = max(along(p) for p in pole) + 2
    # The hand: skin touching the pole, nearest the middle of the pole.
    touching = [p for p in pole for e in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if solid((p[0] + e[0], p[1] + e[1])) and px[p[0] + e[0], p[1] + e[1]][:3] in SKIN]
    if touching:
        grip = min(touching, key=lambda p: abs(along(p)))
    else:
        # No hand found on it: hold it at the pole pixel nearest the body's middle.
        grip = min(pole, key=lambda p: abs(p[0] - w / 2) + abs(p[1] - h * 0.6))
    # Which way the crystal end lies along the line.
    tip_sign = 1.0
    if crystal:
        tip_sign = 1.0 if sum(along(p) for p in crystal) / len(crystal) > along(grip) else -1.0
    kept = {}
    for y in range(h):
        for x in range(w):
            p = (x, y)
            if px[p][3] == 0:
                continue
            c = px[p][:3]
            on_line = across(p) <= REACH and lo <= along(p) <= hi
            if c in CRYSTAL or (on_line and (c in POLE or c in DARK)):
                if on_line and abs(along(p) - along(grip)) <= KEEP and c not in CRYSTAL:
                    kept[p] = px[p]
                px[p] = (0, 0, 0, 0)
    # Any staff wood left off the line (the staff isn't always drawn quite straight) goes, with its outline.
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0 and px[x, y][:3] in POLE and (x, y) not in kept:
                px[x, y] = (0, 0, 0, 0)
                for e in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    r = (x + e[0], y + e[1])
                    if solid(r) and px[r][:3] in DARK and r not in kept:
                        px[r] = (0, 0, 0, 0)
    for p, c in kept.items():
        px[p] = c
    # Bits of the staff left floating on their own (its carved head, a stray edge) go too.
    seen = set()
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or px[x, y][3] == 0:
                continue
            group, stack = [], [(x, y)]
            seen.add((x, y))
            while stack:
                q = stack.pop()
                group.append(q)
                for e in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                    r = (q[0] + e[0], q[1] + e[1])
                    if r not in seen and solid(r):
                        seen.add(r)
                        stack.append(r)
            staffish = all(px[q][:3] in POLE or px[q][:3] in DARK or px[q][:3] in CRYSTAL for q in group)
            if staffish and len(group) < 40 and not any(q in kept for q in group):
                for q in group:
                    px[q] = (0, 0, 0, 0)
    # A crystal on the tip of the wand.
    if kept:
        far = max(kept, key=lambda p: (along(p) - along(grip)) * tip_sign)
        for (ex, ey, c) in [(0, 0, (51, 218, 255)), (0, -1, (193, 255, 250)), (1, 0, (51, 218, 255)),
                            (-1, 0, (51, 218, 255)), (0, 1, (51, 218, 255))]:
            q = (far[0] + ex, far[1] + ey)
            if 0 <= q[0] < w and 0 <= q[1] < h:
                px[q] = c + (255,)
    return im, True




def build_extras(dl, props, tiles):
    """Pieces cut from sheets and recoloured: the wand and staff, rock spikes, clouds, ice and quicksand."""
    tiny = Image.open(os.path.join(dl, "x_tinydungeon/Tilemap/tilemap_packed.png")).convert("RGBA")
    for name, index in [("wand", 129), ("staff", 130)]:
        cell = tiny.crop(((index % 12) * 16, (index // 12) * 16, (index % 12) * 16 + 16, (index // 12) * 16 + 16))
        cell.crop(alpha_box(cell)).save(os.path.join(props, name + ".png"), optimize=True)
    # Rock spikes for Fissure: the rising ice spikes, recoloured to stone.
    rocks = Image.open(os.path.join(dl, "icicles/icerocks_pixel.png")).convert("RGBA")
    rock_ramp = ("ramp", (34, 24, 20), (196, 170, 140))
    for i, (x, y) in enumerate([(48, 48), (32, 48), (48, 32)]):
        cell = recolour(rocks.crop((x, y, x + 16, y + 16)), rock_ramp)
        cell.crop(alpha_box(cell)).save(os.path.join(props, "rock_spike_%d.png" % (i + 1)), optimize=True)
    # Clouds, keyed off their sky and turned to storm and snow clouds.
    clouds = key_out(Image.open(os.path.join(dl, "x_clouds/pix/pixel_art_clouds/clouds.png")).convert("RGBA"))
    for name, box in [("big", (0, 60, 120, 120)), ("small_1", (70, 0, 120, 30)), ("small_2", (70, 28, 120, 58))]:
        cell = clouds.crop(box)
        cell = cell.crop(alpha_box(cell))
        recolour(cell, ("ramp", (22, 18, 34), (112, 104, 140))).save(os.path.join(props, "cloud_storm_%s.png" % name), optimize=True)
        recolour(cell, ("ramp", (70, 86, 112), (232, 242, 255))).save(os.path.join(props, "cloud_snow_%s.png" % name), optimize=True)
    # Ice: the church's cut stone, recoloured, for ice blocks; and one plain block of it to fill shapes with.
    ice_ramp = ("ramp", (18, 58, 96), (228, 248, 255))
    stone = Image.open(os.path.join(tiles, "stone.png")).convert("RGBA")
    recolour(stone, ice_ramp).save(os.path.join(tiles, "ice.png"), optimize=True)
    church = Image.open(os.path.join(dl, CHURCH + "tileset.png")).convert("RGBA")
    recolour(church.crop((64, 112, 96, 144)), ice_ramp).save(os.path.join(props, "ice_fill.png"), optimize=True)
    # Quicksand: the swamp's murky water, turned to churning sand.
    swamp = Image.open(os.path.join(dl, SWAMP + "tileset.png")).convert("RGBA")
    recolour(swamp.crop((224, 80, 288, 112)), ("ramp", (52, 34, 16), (226, 186, 120))).save(os.path.join(props, "quicksand.png"), optimize=True)


def strip(frames, dst):
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    out = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        out.paste(f, (i * w + (w - f.width) // 2, h - f.height))
    out.save(dst, optimize=True)
    return w, h, len(frames)


def write_meta(chars, fx):
    lines = ['class_name PixelArt', '',
             '## Made by tools/prepare_gothic_art.py. Do not edit by hand: run the tool again instead.',
             '## CHARACTERS: each one\'s frame size in pixels, and the box around its body measured from its anchor (the',
             '## bottom middle of the frame for walkers, the middle for flyers). FX: each effect strip\'s frame size and count.',
             '', 'const CHARACTERS := {']
    for name, m in chars.items():
        x, y, w, h = m["body"]
        lines.append('\t"%s": {"size": Vector2(%d, %d), "body": Rect2(%.1f, %.1f, %.1f, %.1f), "flyer": %s},'
                     % (name, m["size"][0], m["size"][1], x, y, w, h, "true" if m["flyer"] else "false"))
    lines += ['}', '', 'const FX := {']
    for name, (w, h, n) in fx.items():
        lines.append('\t"%s": {"size": Vector2(%d, %d), "frames": %d},' % (name, w, h, n))
    lines += ['}', '']
    with open(os.path.join(ROOT, "scripts", "pixel_art.gd"), "w", newline="\n") as f:
        f.write("\n".join(lines))


def main():
    dl = sys.argv[1] if len(sys.argv) > 1 else "."
    chars = {}
    for name in MOBS + HEROES:
        chars[name] = prepare_character(name, dl)
        print(name, chars[name])

    wand_dir = os.path.join(ROOT, "art", "chars", "wizard_wand")
    shutil.rmtree(wand_dir, ignore_errors=True)
    os.makedirs(wand_dir)
    for f in glob.glob(os.path.join(ROOT, "art", "chars", "wizard", "*.png")):
        wandify(Image.open(f).convert("RGBA"))[0].save(os.path.join(wand_dir, os.path.basename(f)), optimize=True)

    tiles = os.path.join(ROOT, "art", "tiles")
    os.makedirs(tiles, exist_ok=True)
    for name, spec in TILESETS.items():
        build_atlas(spec, dl, os.path.join(tiles, name + ".png"))

    props = os.path.join(ROOT, "art", "props")
    os.makedirs(props, exist_ok=True)
    for name, src in PROPS.items():
        im = Image.open(os.path.join(dl, src)).convert("RGBA")
        im.crop(alpha_box(im)).save(os.path.join(props, name + ".png"), optimize=True)
    for name, (src, box) in PROP_CUTS.items():
        im = Image.open(os.path.join(dl, src)).convert("RGBA").crop(box)
        im.crop(alpha_box(im)).save(os.path.join(props, name + ".png"), optimize=True)

    for place, layers in BACKDROPS.items():
        out = os.path.join(ROOT, "art", "backgrounds", place)
        os.makedirs(out, exist_ok=True)
        for name, src, box in layers:
            im = Image.open(os.path.join(dl, src)).convert("RGBA")
            (im.crop(box) if box else im).save(os.path.join(out, name + ".png"), optimize=True)
    # The cathedral's wall is one long strip of its panels: window, pillar, altar, pillar, gargoyle, pillar.
    church = os.path.join(ROOT, "art", "backgrounds", "church")
    panels = [Image.open(os.path.join(church, n + ".png")) for n in ["far", "mid", "near", "mid", "gargoyle", "mid"]]
    hall = Image.new("RGBA", (sum(p.width for p in panels), 192))
    x = 0
    for panel in panels:
        hall.paste(panel, (x, 0))
        x += panel.width
    hall.save(os.path.join(church, "hall.png"), optimize=True)
    # The swamp's two middle layers are two stretches of the same woods; side by side they make one longer strip.
    swamp = os.path.join(ROOT, "art", "backgrounds", "swamp")
    a, b = Image.open(os.path.join(swamp, "far.png")), Image.open(os.path.join(swamp, "mid.png"))
    woods = Image.new("RGBA", (a.width + b.width, a.height))
    woods.paste(a, (0, 0))
    woods.paste(b, (a.width, 0))
    woods.save(os.path.join(swamp, "woods.png"), optimize=True)

    fx_dir = os.path.join(ROOT, "art", "fx")
    os.makedirs(fx_dir, exist_ok=True)
    fx = {}
    for name, (pattern, count) in FX.items():
        # Some packs leave the number off the first frame (Icespear.png, Icespear2.png...).
        paths = [os.path.join(dl, pattern.format(i + 1)) for i in range(count)]
        if not os.path.exists(paths[0]):
            paths[0] = os.path.join(dl, pattern.format(""))
        frames = [Image.open(p).convert("RGBA") for p in paths]
        fx[name] = strip(frames, os.path.join(fx_dir, name + ".png"))
    for name, (src, fw) in FX_SHEETS.items():
        sheet = Image.open(os.path.join(dl, src)).convert("RGBA")
        fx[name] = strip(frames_of(sheet, fw, sheet.height), os.path.join(fx_dir, name + ".png"))
    for name, (src, fw, fh) in FX_GRIDS.items():
        sheet = Image.open(os.path.join(dl, src)).convert("RGBA")
        cells = [sheet.crop((x, y, x + fw, y + fh)) for y in range(0, sheet.height, fh) for x in range(0, sheet.width, fw)]
        fx[name] = strip(cells, os.path.join(fx_dir, name + ".png"))
    for name, (src, fw, fh, how) in FX_RECOLOURED.items():
        sheet = Image.open(os.path.join(dl, src)).convert("RGBA")
        fx[name] = strip([recolour(f, how) for f in grid_frames(sheet, fw, fh)], os.path.join(fx_dir, name + ".png"))
    build_extras(dl, os.path.join(ROOT, "art", "props"), os.path.join(ROOT, "art", "tiles"))
    # The spellbook: closed, opening, open and turning a page, seven frames of 190 x 160.
    os.makedirs(os.path.join(ROOT, "art", "ui"), exist_ok=True)
    shutil.copy(os.path.join(dl, "books/foxel/RADL_Book.png"), os.path.join(ROOT, "art", "ui", "book.png"))
    write_meta(chars, fx)


if __name__ == "__main__":
    main()
