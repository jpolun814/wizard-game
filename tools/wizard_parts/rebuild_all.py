"""Runs the WHOLE character-parts pipeline, in the right order, so nothing is forgotten. Run from anywhere:

    python tools/wizard_parts/rebuild_all.py              # everything (about 3 minutes)
    python tools/wizard_parts/rebuild_all.py hat weapon   # only these slots' sheets are redrawn and repacked
                                                          # (previews, reference and checks still run)
    options: --no-pack  --no-aseprite  --no-check

Steps (docs/handoff/20_making_wizard_parts.md explains each):
 1. build.py           draw the sheets            -> art_source/parts_sheets/<slot>/<variant>.png + manifest.json
 2. (full builds only) delete sheets/packed files of variants that no longer exist
 3. copy manifest.json                            -> art/parts/manifest.json (the game reads this copy)
 4. tools/pack_parts.gd pack sheets for the game  -> art/parts/<slot>/<variant>.parts   (Godot, headless)
 5. make_test.py       compose the test character + lineup from the sheets, write the preview GIFs
                                                  -> art_source/wizard_parts_preview/
 6. copy the test character's sheet + config      -> art_source/parts_sheets/reference/ (parts_check compares to it)
 7. layered.lua        a layered .aseprite of the test character (Aseprite, batch mode)
 8. edge_check.py      nothing may touch the frame edge
 9. tests/checks/parts_check.tscn                 the game's own check of the packed parts (Godot, headless)
"""
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
SHEETS = os.path.join(GAME, "art_source", "parts_sheets")
PACKED = os.path.join(GAME, "art", "parts")
PREVIEW = os.path.join(GAME, "art_source", "wizard_parts_preview")
GODOT = os.environ.get("GODOT", "C:/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
ASEPRITE = os.environ.get("ASEPRITE", "C:/Users/Jordan Polun/Desktop/aseprite/build/bin/aseprite.exe")


def step(title, command, cwd=HERE, must=True):
    print(f"\n=== {title}\n    {' '.join(command)}", flush=True)
    result = subprocess.run(command, cwd=cwd)
    if result.returncode != 0 and must:
        sys.exit(f"FAILED: {title} (exit {result.returncode})")
    return result.returncode == 0


def main():
    args = sys.argv[1:]
    flags = {a for a in args if a.startswith("--")}
    slots = [a for a in args if not a.startswith("--")]
    py = sys.executable

    step("1. draw the sheets", [py, "build.py", SHEETS] + slots)

    manifest = json.load(open(os.path.join(SHEETS, "manifest.json")))
    if not slots:
        print("\n=== 2. remove variants that no longer exist")
        for s in manifest["slots"]:
            keep = set(s["variants"])
            for folder, ext in ((os.path.join(SHEETS, s["name"]), ".png"), (os.path.join(PACKED, s["name"]), ".parts")):
                if not os.path.isdir(folder):
                    continue
                for f in os.listdir(folder):
                    if f.endswith(ext) and f[: -len(ext)] not in keep:
                        os.remove(os.path.join(folder, f))
                        print("    removed stale", os.path.join(folder, f))

    print("\n=== 3. copy manifest.json into art/parts")
    os.makedirs(PACKED, exist_ok=True)
    shutil.copyfile(os.path.join(SHEETS, "manifest.json"), os.path.join(PACKED, "manifest.json"))

    if "--no-pack" not in flags:
        step("4. pack the sheets for the game", [GODOT, "--headless", "--path", ".", "-s", "tools/pack_parts.gd", "--"] + slots,
             cwd=GAME)

    step("5. compose the test character, write the preview GIFs",
         [py, "make_test.py", os.path.join(PREVIEW, "gifs"), os.path.join(PREVIEW, "test_character")])

    print("\n=== 6. refresh the reference parts_check compares against")
    ref = os.path.join(SHEETS, "reference")
    os.makedirs(ref, exist_ok=True)
    for f in ("test_character_sheet.png", "test_character.json"):
        shutil.copyfile(os.path.join(PREVIEW, "test_character", f), os.path.join(ref, f))

    if "--no-aseprite" not in flags and os.path.exists(ASEPRITE):
        tc = os.path.join(PREVIEW, "test_character")
        step("7. layered .aseprite of the test character",
             [ASEPRITE, "-b", "--script-param", "layers=" + os.path.join(tc, "layers.txt"), "--script-param",
              "anims=" + os.path.join(tc, "anims.txt"), "--script-param", "out=" + os.path.join(tc, "test_character.aseprite"),
              "--script", os.path.join(HERE, "layered.lua")], must=False)

    step("8. edge check", [py, "edge_check.py"])

    if "--no-check" not in flags:
        step("9. the game's parts check", [GODOT, "--headless", "--path", ".", "tests/checks/parts_check.tscn"], cwd=GAME,
             must=False)
    print("\nDone. Look at the GIFs in art_source/wizard_parts_preview/gifs before calling it finished.")


if __name__ == "__main__":
    main()
