"""Copies the soft particle textures and the sounds in from the source packs.

Run from the project root:

    python tools/prepare_art.py <downloads folder>

The downloads folder holds the unzipped packs listed in art/CREDITS.md (Kenney's Particle Pack and audio packs, and
the OpenGameArt sound packs). The pixel art (characters, levels, spell effects) is built by
tools/prepare_gothic_art.py, and the layered spell sounds by tools/make_sounds.py.
"""

import os
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PARTICLES = ["circle_05", "dirt_01", "dirt_02", "dirt_03", "fire_01", "fire_02", "flame_01", "flame_02", "flame_03",
             "flame_04", "flame_05", "flame_06", "flare_01", "light_01", "light_02", "light_03", "magic_01",
             "magic_02", "magic_03", "magic_04", "magic_05", "scorch_01", "scorch_02", "smoke_01", "smoke_02",
             "smoke_04", "smoke_07", "spark_01", "spark_02", "spark_03", "spark_04", "spark_05", "spark_06",
             "spark_07", "star_01", "star_04", "star_06", "star_07", "symbol_01", "symbol_02", "trace_01",
             "trace_02", "trace_04", "twirl_01", "twirl_02", "twirl_03", "circle_01", "circle_02", "circle_03",
             "muzzle_01", "slash_01", "window_01"]

# Sound name in the game -> file in the downloads folder.
# spark, blink, push and fire_breath are mixed from several recordings by tools/make_sounds.py.
SOUNDS = {
    "cast_fire": "oga/80-CC0-RPG-SFX_0/spell_fire_04.ogg",
    "fire_hit": "oga/80-CC0-RPG-SFX_0/spell_fire_07.ogg",
    "fire_wall": "oga/80-CC0-RPG-SFX_0/spell_fire_05.ogg",
    "volcano": "oga/105016__julien-matthey__jm-fx-fireball-01.wav",
    "cast_ice": "oga/icespells/ice.wav",
    "ice_shatter_1": "oga/100-CC0-SFX_0/glass_01.ogg",
    "ice_shatter_2": "oga/100-CC0-SFX_0/glass_02.ogg",
    "ice_shatter_3": "oga/100-CC0-SFX_0/glass_03.ogg",
    "freeze": "oga/freeze.wav",
    "snow": "oga/icespells/coldsnap.wav",
    "force": "scifi/Audio/forceField_000.ogg",
    "barrier": "scifi/Audio/forceField_002.ogg",
    "gravity": "oga/magical_4.ogg",
    "thunder": "oga/sfx_100_v2/sfx100v2_thunder_01.ogg",
    "tornado": "oga/sfx_100_v2/sfx100v2_air_01.ogg",
    "earth": "oga/Earth%20Element%20Magic%20Spell_3.ogg",
    "stones_1": "oga/80-CC0-RPG-SFX_0/stones_01.ogg",
    "stones_2": "oga/80-CC0-RPG-SFX_0/stones_02.ogg",
    "stones_3": "oga/80-CC0-RPG-SFX_0/stones_04.ogg",
    "quake": "scifi/Audio/lowFrequency_explosion_001.ogg",
    "explosion": "oga/100-CC0-SFX_0/explosion.ogg",
    "misfire": "oga/100-CC0-SFX_0/weird_03.ogg",
    "mob_hurt_1": "oga/80-CC0-creature-SFX_0/hurt_01.ogg",
    "mob_hurt_2": "oga/80-CC0-creature-SFX_0/hurt_02.ogg",
    "mob_hurt_3": "oga/80-CC0-creature-SFX_0/hurt_04.ogg",
    "mob_die_1": "oga/80-CC0-RPG-SFX_0/creature_die_01.ogg",
    "mob_die_2": "oga/80-CC0-creature-SFX_0/monster_05.ogg",
    "mob_shoot": "platformer/Sounds/sfx_throw.ogg",
    "player_hurt": "platformer/Sounds/sfx_hurt.ogg",
    "jump": "platformer/Sounds/sfx_jump.ogg",
    "portal_open": "oga/magical_3.ogg",
    "portal_enter": "oga/magical_1_0.ogg",
    "ritual_ok": "oga/100-CC0-SFX_0/bell_01.ogg",
    "type": "ui_sounds/Audio/click_002.ogg",
    "book_open": "rpg_audio/Audio/bookOpen.ogg",
    "book_close": "rpg_audio/Audio/bookClose.ogg",
    "page_1": "rpg_audio/Audio/bookFlip1.ogg",
    "page_2": "rpg_audio/Audio/bookFlip2.ogg",
    "pickup": "platformer/Sounds/sfx_gem.ogg",
    "heal": "oga/magical_5.ogg",
    "wizard_cast": "oga/magical_7_0.ogg",
    "wave_start": "oga/100-CC0-SFX_0/gong_02.ogg",
    "game_over": "oga/100-CC0-SFX_0/gong_01.ogg",
    "summon": "oga/magical_6_0.ogg",
    "ui_click": "ui_sounds/Audio/click_001.ogg",
    "step_1": "impact/Audio/footstep_grass_000.ogg",
    "step_2": "impact/Audio/footstep_grass_002.ogg",
    "step_3": "impact/Audio/footstep_grass_004.ogg",
}


def copy_scaled(src, dst, size=None):
    im = Image.open(src).convert("RGBA")
    if size:
        im = im.resize((int(im.width * size / max(im.size)), int(im.height * size / max(im.size))), Image.LANCZOS)
    im.save(dst, optimize=True)


def main():
    downloads = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(os.path.join(ROOT, "art", "particles"), exist_ok=True)
    for p in PARTICLES:
        copy_scaled(os.path.join(downloads, "particles", "PNG (Transparent)", p + ".png"),
                    os.path.join(ROOT, "art", "particles", p + ".png"), 128)
    os.makedirs(os.path.join(ROOT, "audio"), exist_ok=True)
    for name, src in SOUNDS.items():
        ext = os.path.splitext(src)[1]
        shutil.copy(os.path.join(downloads, src), os.path.join(ROOT, "audio", name + ext))


if __name__ == "__main__":
    main()
