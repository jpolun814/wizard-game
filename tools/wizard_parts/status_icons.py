"""The little pictures in the status bubbles that ring a wizard (scripts/wizard/status_bubbles.gd). Each is 9x9 pixels drawn here as text; a = the main
color, b = its highlight, c = its shade, d = a second color. Run it from anywhere:

    python tools/wizard_parts/status_icons.py

It writes art/fx/status_icons.png, one icon after another, left to right, in the order of ICONS. Never edit the PNG by hand: change this file and run it.
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SIZE = 9

# name: (colors, rows)
ICONS = [
    ("frozen", {"a": "#9fe3ff", "b": "#ffffff", "c": "#4f9bd0"}, [
        "....a....", ".a..a..a.", "..a.a.a..", "...aaa...", "aaaabaaaa", "...aaa...", "..a.a.a..", ".a..a..a.", "....a...."]),
    ("slowed", {"a": "#c9a36a", "b": "#f0d9a8", "c": "#7a5a34"}, [
        "..aaaaa..", ".abbbbba.", "ab.bbb.ba", "a..bbb..a", "a.b.b.b.a", "a..bbb..a", "ac.bbb.ca", ".acccccca", "..aaaaa.."]),
    ("dazed", {"a": "#f0d060", "b": "#fffbd0", "c": "#a08a1a"}, [
        "....b....", "....a....", "..a.a.a..", "...aba...", "bbaabaabb", "...aba...", "..a.a.a..", "....a....", "....b...."]),
    ("hexed", {"a": "#b04ae0", "b": "#e6a8ff", "c": "#5c1f80"}, [
        "....a....", "....a....", "...aba...", "aaaabaaaa", ".aabbbaa.", "..abbba..", "..aa.aa..", ".aa...aa.", ".a.....a."]),
    ("silenced", {"a": "#8a8aa8", "b": "#d8d8ee", "c": "#3a3a52", "d": "#e0484e"}, [
        "..bbbbb..", ".bb...bb.", "bb.....bb", "b.......b", "bb.....bb", ".bb...bb.", "..bbbbb..", "d.......d", ".ddddddd."]),
    ("holding", {"a": "#e89aa8", "b": "#ffd8de", "c": "#9a4658", "d": "#bfeaff"}, [
        "....d....", "....d....", "...ada...", ".aa.d.aa.", "abba.abba", "abba.abba", "abba.abba", ".acc...cc.".replace("...cc.", "..cc."), "..cc.cc.."]),
    ("choking", {"a": "#e8584e", "b": "#ffb0a8", "c": "#7a1a1a"}, [
        "...aaa...", "..abbba..", ".abaaaca.", ".aba.aca.", ".abaaaca.", "..accca..", "...aaa...", "a.......a", ".aaaaaaa."]),
    ("confused", {"a": "#e0302a", "b": "#ff9a60", "c": "#701010"}, [
        "a.......a", "aa.....aa", ".aa.b.aa.", "..aabaa..", "...aba...", "..a.b.a..", ".aa...aa.", ".ac...ca.", "cc.....cc"]),
    ("fleeing", {"a": "#f0e060", "b": "#fffbd0", "c": "#a08a1a"}, [
        "...aa....", "..abba...", "...aa.a..", "..aaaa.a.", ".aaaa..a.", "..a.a..a.", ".a...a.a.", "a.....a..", "........."]),
    ("bleeding", {"a": "#c01834", "b": "#ff7088", "c": "#6a0a1a"}, [
        "....a....", "....a....", "...aaa...", "...aba...", "..aabaa..", ".aaabaaa.", ".aaaaaca.", "..aacca..", "...ccc..."]),
    ("veiled", {"a": "#9a1c30", "b": "#e0647a", "c": "#4a0a18"}, [
        "..aaaaa..", ".abbbbba.", "ab.....ba", "a.b...b.a", "a..b.b..a", ".a..b..a.", ".ac.b.ca.", "..ac.ca..", "...ccc..."]),
    ("hasted", {"a": "#7ad0ff", "b": "#e0f6ff", "c": "#2a7ab0"}, [
        ".....bb..", "....bba..", "...bbaa..", "..bbaa...", ".bbbbbbb.", "...aabb..", "..aabb...", ".aabb....", ".ab......"]),
    ("adrenaline", {"a": "#ff9a2a", "b": "#ffe08a", "c": "#a04a10"}, [
        "....aa...", "...aab...", "..aab....", ".aabbbbb.", "...aab...", "..aab....", ".aab.....", "aab......", "ab......."]),
    ("unlimited", {"a": "#5cf0a0", "b": "#d8ffe8", "c": "#1a8a56"}, [
        ".........", ".aaa.aaa.", "ab..a..ba", "a...a...a", "a..b.b..a", "a...a...a", "ab..a..ba", ".aaa.aaa.", "........."]),
    ("extra_jump", {"a": "#e8e8f0", "b": "#ffffff", "c": "#8a8aa0"}, [
        "....a....", "...aba...", "..ab.ba..", ".ab.a.ba.", "....a....", "...aba...", "..ab.ba..", ".ab...ba.", "........."]),
    ("wet", {"a": "#4aa8ff", "b": "#bfe4ff", "c": "#1e5eb0"}, [
        "....a....", "....a....", "...aba...", "...aba...", "..aabaa..", ".aaabaaa.", ".aaaaaaa.", "..aaaaa..", "...ccc..."]),
    ("burning", {"a": "#ff7a1a", "b": "#ffe060", "c": "#b02a0a"}, [
        "....a....", "...aa....", "...aaa.a.", "..aabaaa.", ".aaabbaa.", ".aabbbaa.", ".aabbbaa.", "..aabaa..", "...ccc..."]),
    ("oiled", {"a": "#6a5a9a", "b": "#b8a8e8", "c": "#241a3a"}, [
        "....c....", "....c....", "...ccc...", "...cac...", "..ccbcc..", ".cccbccc.", ".ccccccc.", "..ccccc..", "...ccc..."]),
    ("cross", {"a": "#ff2a2a", "b": "#ff8a8a"}, [
        "a.......a", ".ab...ba.", "..ab.ba..", "...aba...", "....a....", "...aba...", "..ab.ba..", ".ab...ba.", "a.......a"]),
]


def main():
    sheet = Image.new("RGBA", (SIZE * len(ICONS), SIZE), (0, 0, 0, 0))
    for n, (name, colors, rows) in enumerate(ICONS):
        assert len(rows) == SIZE and all(len(r) == SIZE for r in rows), name
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    sheet.putpixel((n * SIZE + x, y), Image.new("RGB", (1, 1), colors[ch]).getpixel((0, 0)) + (255,))
    path = os.path.join(ROOT, "art", "fx", "status_icons.png")
    sheet.save(path)
    print("wrote", path, [name for name, _, _ in ICONS])


main()
