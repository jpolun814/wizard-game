"""Makes art/tiles/podium.png, the stone of the stairs the spellbook's pedestal stands on: the church tile set (art/tiles/church.png, from the Gothicvania Church by
ansimuz, CC0) with its eight colors turned, darkest to lightest, to a ramp of grays like the pedestal's own (art/props/lectern_stand.png), so that the two match.

    python tools/prepare_podium.py
"""
from PIL import Image


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def turned(source, grays, out):
    im = Image.open(source).convert("RGBA")
    colors = sorted({p[:3] for p in im.getdata() if p[3] > 0}, key=lum)
    ramp = [grays[0] + (grays[-1] - grays[0]) * k / (len(colors) - 1) for k in range(len(colors))]
    mapping = {c: (round(g),) * 3 for c, g in zip(colors, ramp)}
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a > 0:
                px[x, y] = mapping[(r, g, b)] + (a,)
    im.save(out)
    print("wrote", out, "from", len(colors), "colors")


turned("art/tiles/church.png", [44, 152], "art/tiles/podium.png")  # the pedestal's grays run from 63 (its shade) to 152 (its lit edge)
