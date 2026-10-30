"""Makes art/props/jungle_vine.png: the swamp vine (already in art/props, from GothicVania Swamp by ansimuz, CC0) turned upright, two
pieces one above the other (the second flipped), so that it tiles down a hanging vine. Run from the project folder: python -I tools/prepare_jungle.py"""
from PIL import Image, ImageOps

vine = Image.open("art/props/swamp_vine.png").convert("RGBA").rotate(90, expand=True)
out = Image.new("RGBA", (vine.width, vine.height * 2))
out.paste(vine, (0, 0))
out.paste(ImageOps.flip(vine), (0, vine.height))
out.save("art/props/jungle_vine.png", optimize=True)
print(out.size)
