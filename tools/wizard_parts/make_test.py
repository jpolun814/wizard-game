"""Builds test characters purely from the exported part sheets, then writes the GIFs.
usage: python make_test.py [gif_dir] [work_dir]   (defaults: art_source/wizard_parts_preview/gifs and .../test_character)"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compose import compose_sheet, frames_of, load_manifest, variant_key, recolor, PARTS  # noqa: E402

# an original combination - deliberately NOT the sample wizard's look (no purple hood / white beard / cyan crystal)
TEST = dict(skin="tan", outfit="coat", color="blue", hair="short", hair_color="auburn", beard="short",
            beard_color="auburn", hat="wide", hat_color="blue", weapon="staff_orb", trim="gold", boots="brown")
TEST_SPELL = "Fire"
LINEUP = [
    (TEST, "Fire"),
    (dict(skin="pale", outfit="robe", color="crimson", hair="long", hair_color="black", beard="none", beard_color="black",
          hat="pointy", hat_color="charcoal", weapon="wand"), "Shadow"),
    (dict(skin="brown", outfit="tunic", color="emerald", hair="short", hair_color="black", beard="short",
          beard_color="black", hat="none", hat_color="emerald", weapon="staff_branch"), "Flora"),
    (dict(skin="deep", outfit="coat", color="purple", hair="ponytail", hair_color="blonde", beard="none",
          beard_color="blonde", hat="circlet", hat_color="purple", weapon="scepter"), "Water"),
    (dict(skin="light", outfit="tunic", color="charcoal", hair="none", hair_color="gray", beard="short",
          beard_color="gray", hat="hood", hat_color="charcoal", weapon="staff_crystal"), "Blood"),
    (dict(skin="zombie", outfit="robe", color="ivory", hair="bun", hair_color="gray", beard="goatee", beard_color="gray",
          hat="none", hat_color="ivory", weapon="staff_branch"), "Earth"),
]
for _look, _spell in LINEUP:  # the lineup was made before trim and boots were chosen: gold edges and brown boots
    _look.setdefault("trim", "gold")
    _look.setdefault("boots", "brown")
BG = (38, 40, 52)


def on_bg(fr, box, z, ground=True):
    im = fr.crop(box)
    bg = Image.new("RGBA", im.size, BG + (255,))
    if ground:
        ImageDraw.Draw(bg).line([(0, im.height - 1), (im.width, im.height - 1)], fill=(70, 74, 92, 255))
    bg.alpha_composite(im)
    return bg.resize((im.width * z, im.height * z), Image.NEAREST).convert("RGB")


def label(im, text):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 8 + 6 * len(text), 20], fill=(20, 22, 30))
    d.text((5, 4), text, fill=(235, 235, 240))
    return im


def save_gif(path, frames, durs):
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=durs, loop=0, disposal=2)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art_source", "wizard_parts_preview")
    gif_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "gifs")
    work = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, "test_character")
    os.makedirs(gif_dir, exist_ok=True)
    os.makedirs(work, exist_ok=True)
    man = load_manifest()
    sheet = compose_sheet(TEST, spell=TEST_SPELL)
    sheet.save(os.path.join(work, "test_character_sheet.png"))
    json.dump(dict(TEST, spell_shown=TEST_SPELL), open(os.path.join(work, "test_character.json"), "w"), indent=1)
    with open(os.path.join(work, "layers.txt"), "w") as f:  # for layered.lua
        for s in man["slots"]:
            path = os.path.join(PARTS, s["name"], variant_key(s["name"], s["depends_on"], TEST, s.get("alias")) + ".png")
            if not os.path.exists(path):
                continue
            if s["name"] == man["magic"]["slot"]:  # show the magic layer in a spell colour in Aseprite
                spath = os.path.join(work, "magic_" + TEST_SPELL + ".png")
                recolor(Image.open(path).convert("RGBA"), [tuple(c) for c in man["magic"]["example_spells"][TEST_SPELL]]).save(spath)
                path = spath
            f.write(f"{s['name']}|{os.path.abspath(path)}\n")
    with open(os.path.join(work, "anims.txt"), "w") as f:  # animation list for layered.lua
        for name, a in man["animations"].items():
            f.write(f"{name}|{a['count']}|{a['fps']}\n")

    # ---- the test character: one GIF per animation + all of them
    box, z = (30, 0, 254, 138), 3
    all_f, all_d = [], []
    for name, a in man["animations"].items():
        ms = int(round(1000 / a["fps"]))
        fr = [on_bg(f, box, z) for f in frames_of(sheet, man, name)]
        durs = [ms] * len(fr)
        if not a["loop"]:
            durs[-1] = ms + 500  # hold the last frame of one-shot animations so the loop reads
        save_gif(os.path.join(gif_dir, f"{name}.gif"), fr, durs)
        small = [on_bg(f, box, 2) for f in frames_of(sheet, man, name)]
        for _ in range((3 if a["count"] <= 4 else 2) if a["loop"] else 1):
            for i, f in enumerate(small):
                all_f.append(label(f.copy(), f"{name} {i}"))
                all_d.append(durs[i])
    save_gif(os.path.join(gif_dir, "all_animations.gif"), all_f, all_d)

    # ---- lineup: very different characters from the same parts, each with a different spell colour
    sheets = [compose_sheet(c, spell=s) for c, s in LINEUP]
    json.dump([dict(c, spell_shown=s) for c, s in LINEUP], open(os.path.join(work, "lineup_characters.json"), "w"), indent=1)
    seq = [("idle", 2), ("run", 3), ("cast", 2), ("release", 1), ("jump", 1), ("fall", 3), ("hit", 1), ("death", 1),
           ("wake", 1), ("walk", 2), ("swim", 2), ("climb", 2), ("float", 3), ("pulled", 2), ("knockback", 3),
           ("get_up", 1), ("cast_sky", 1), ("cast_ground", 1), ("beam", 3), ("sweep", 1), ("empower", 1), ("victory", 1)]
    lb, lz = (66, 0, 254, 138), 2
    cw, chh = (lb[2] - lb[0]) * lz, (lb[3] - lb[1]) * lz
    frames, durs = [], []
    for name, reps in seq:
        a = man["animations"][name]
        per = [frames_of(s, man, name) for s in sheets]
        for _ in range(reps):
            for i in range(a["count"]):
                row = Image.new("RGB", (cw * 3, chh * 2), BG)
                for k in range(6):
                    row.paste(on_bg(per[k][i], lb, lz), ((k % 3) * cw, (k // 3) * chh))
                frames.append(label(row, name))
                durs.append(int(round(1000 / a["fps"])) + (500 if (not a["loop"] and i == a["count"] - 1) else 0))
    save_gif(os.path.join(gif_dir, "lineup_mix_and_match.gif"), frames, durs)

    # ---- the same character casting in each example spell colour (the game picks the colour per spell)
    spells = list(man["magic"]["example_spells"])
    ss = [compose_sheet(TEST, spell=s) for s in spells]
    frames, durs = [], []
    for name, reps in (("cast", 2), ("release", 1)):
        a = man["animations"][name]
        per = [frames_of(s, man, name) for s in ss]
        for _ in range(reps):
            for i in range(a["count"]):
                row = Image.new("RGB", (cw * len(spells), chh), BG)
                for k in range(len(spells)):
                    row.paste(label(on_bg(per[k][i], lb, lz), spells[k]), (k * cw, 0))
                frames.append(row)
                durs.append(int(round(1000 / a["fps"])) + (400 if (not a["loop"] and i == a["count"] - 1) else 0))
    save_gif(os.path.join(gif_dir, "spell_colors.gif"), frames, durs)
    print("ok:", len(all_f), "frames in all_animations.gif")


if __name__ == "__main__":
    main()
