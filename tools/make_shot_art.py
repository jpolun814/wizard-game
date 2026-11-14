"""Draws the small pixel sprites of the new shots, pixel by pixel: a thorn (Barbs), a pebble (Pebble), a hailstone (Hailstorm) and an insect (Insect Plague).

No outside source. They are stand-ins, a few pixels each, for the owner to look at before real art is chosen (see docs/handoff/14).
Run:  python tools/make_shot_art.py   (then `godot --headless --path . --import`)
"""
from PIL import Image
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "fx")

# One letter a color; '.' is clear.
KEY = {
    "d": (38, 66, 34, 255),     # deep green shaft
    "g": (74, 128, 56, 255),    # green
    "l": (132, 190, 96, 255),   # lit green
    "t": (226, 214, 170, 255),  # pale tip
    "w": (150, 124, 88, 255),   # stone
    "s": (104, 84, 62, 255),    # stone shadow
    "h": (196, 172, 134, 255),  # stone light
    "i": (214, 240, 255, 255),  # ice
    "j": (150, 200, 235, 255),  # ice shade
    "k": (90, 140, 200, 255),   # ice dark
    "b": (34, 30, 22, 255),     # an insect's body
    "v": (205, 205, 195, 190),  # its wings
}

SPRITES = {
    # points to the right, so its head is on the right edge
    "thorn": [
        "dddgg.......",
        ".dgggllttt..",
        "dddgg.......",
    ],
    "pebble": [
        ".hhw..",
        "hhwwws",
        "hwwwss",
        ".wsss.",
    ],
    "hailstone": [
        ".ii.",
        "iijj",
        "ijjk",
        ".jk.",
    ],
    # two frames side by side, wings up and wings out, one insect of a swarm
    "insect": [
        "v...v.....",
        ".vbv.vbbbv",
        "..b.....b.",
        "..b.....b.",
    ],
}

for name, rows in SPRITES.items():
    width = max(len(r) for r in rows)
    image = Image.new("RGBA", (width, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                image.putpixel((x, y), KEY[ch])
    image.save(os.path.join(OUT, name + ".png"))
    print("wrote", name, image.size)
