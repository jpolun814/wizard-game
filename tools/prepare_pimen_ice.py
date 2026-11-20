"""Cuts the Frostbolt's ice shard and its burst from pimen's "Ice Spell Effect 01" (see art/CREDITS.md).

    python -I tools/prepare_pimen_ice.py "<folder the rar was unpacked into>/Ice Effect 01"

The source frames are 48x32. Each strip written here is those frames side by side, each set in the middle of a 48x48 square (the shape PixelFx.square_frames
reads), in the order they play. The shard's last hit frame is empty and is left out.
"""
import sys
from PIL import Image

W, H, SIDE = 48, 32, 48
folder = sys.argv[1] + "/Ice VFX 1"
parts = {
    "pimen_ice": ("IceVFX 1 Repeatable.png", range(10)),
    "pimen_ice_hit": ("Ice VFX 1 Hit.png", range(7)),
}
for name, (source, cells) in parts.items():
    sheet = Image.open(f"{folder}/{source}").convert("RGBA")
    strip = Image.new("RGBA", (SIDE * len(cells), SIDE))
    for i, c in enumerate(cells):
        strip.paste(sheet.crop((c * W, 0, (c + 1) * W, H)), (i * SIDE, (SIDE - H) // 2))
    strip.save(f"art/fx/{name}.png")
    print(name, len(cells), "frames")
