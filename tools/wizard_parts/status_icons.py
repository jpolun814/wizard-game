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
        "aaaaaaaaa", ".a.....a.", ".a.bbb.a.", "..a.b.a..", "...a.a...", "..a.c.a..", ".a.ccc.a.", ".acccccca", "aaaaaaaaa"]),
    ("dazed", {"a": "#f0d060", "b": "#fffbd0"}, [
        "....a....", "...aaa...", "....a....", ".........", "....b....", ".a.....a.", "aaa...aaa", ".a.....a.", "........."]),
    ("hexed", {"a": "#b04ae0", "b": "#e6a8ff", "c": "#5c1f80"}, [
        "....a....", "....a....", "...aba...", "aaaabaaaa", ".aabbbaa.", "..abbba..", "..aa.aa..", ".aa...aa.", ".a.....a."]),
    ("silenced", {"b": "#e0484e"}, [
        "..bbbbb..", ".bb...bb.", "b.....b.b", "b....b..b", "b...b...b", "b..b....b", "b.b.....b", ".bb...bb.", "..bbbbb.."]),
    ("holding", {"a": "#e89aa8", "b": "#ffd8de", "c": "#9a4658", "d": "#bfeaff"}, [
        "....d....", "....d....", "...ada...", ".aa.d.aa.", "abba.abba", "abba.abba", "abba.abba", ".acc...cc.".replace("...cc.", "..cc."), "..cc.cc.."]),
    ("choking", {"a": "#e8584e", "b": "#ffb0a8", "c": "#7a1a1a", "d": "#ff3a3a"}, [
        "....d....", "....d....", "...ada...", ".aa.d.aa.", "abba.abba", "abba.abba", "abba.abba", ".acc...cc.".replace("...cc.", "..cc."), "..cc.cc.."]),
    ("confused", {"a": "#c58cf0", "b": "#ecd0ff", "c": "#6a3a9a"}, [
        "..aaaaa..", ".abbbbba.", ".ab...ba.", ".....ba..", "....ba...", "...ba....", "...ba....", ".........", "...ca...."]),
    ("fleeing", {"a": "#f0e060", "b": "#fffbd0", "c": "#a08a1a"}, [
        "....aa...", "....aa...", "..aaaa.a.", ".a.aa.a..", "...aaa...", "..aa.aa..", ".aa...a..", "aa....aa.", "........."]),
    ("bleeding", {"a": "#c01834", "b": "#ff7088", "c": "#6a0a1a"}, [
        "....a....", "....a....", "...aaa...", "...aba...", "..aabaa..", ".aaabaaa.", ".aaaaaca.", "..aacca..", "...ccc..."]),
    ("veiled", {"a": "#5a0a18", "b": "#d8283c", "c": "#8a1424", "d": "#ff8a98"}, [
        "aaaaaaaaa", "abbbbbbba", "abdbbbbca", "abdbbbbca", "abbbbbcca", ".abbbbcca", "..abbbca.", "...abca..", "....a...."]),
    ("hasted", {"a": "#7ad0ff", "b": "#e0f6ff", "c": "#2a7ab0"}, [
        ".....bb..", "....bba..", "...bbaa..", "..bbaa...", ".bbbbbbb.", "...aabb..", "..aabb...", ".aabb....", ".ab......"]),
    ("adrenaline", {"a": "#ff9a2a", "b": "#ffe08a", "c": "#a04a10"}, [
        "....aa...", "...aab...", "..aab....", ".aabbbbb.", "...aab...", "..aab....", ".aab.....", "aab......", "ab......."]),
    ("unlimited", {"a": "#5cf0a0", "b": "#d8ffe8", "c": "#1a8a56"}, [
        ".........", ".........", ".aa...aa.", "a..a.a..a", "a...a...a", "a..a.a..a", ".aa...aa.", ".........", "........."]),
    ("extra_jump", {"a": "#e8e8f0", "b": "#ffffff", "c": "#8a8aa0"}, [
        "....a....", "...aba...", "..ab.ba..", ".ab.a.ba.", "....a....", "...aba...", "..ab.ba..", ".ab...ba.", "........."]),
    ("wet", {"a": "#4aa8ff", "b": "#bfe4ff", "c": "#1e5eb0"}, [
        "....a....", "....a....", "...aba...", "...aba...", "..aabaa..", ".aaabaaa.", ".aaaaaaa.", "..aaaaa..", "...ccc..."]),
    ("burning", {"a": "#ff7a1a", "b": "#ffe060", "c": "#b02a0a"}, [
        "....a....", "...aa....", "...aaa.a.", "..aabaaa.", ".aaabbaa.", ".aabbbaa.", ".aabbbaa.", "..aabaa..", "...ccc..."]),
    ("oiled", {"a": "#6a5a9a", "b": "#b8a8e8", "c": "#241a3a"}, [
        "....c....", "....c....", "...ccc...", "...cac...", "..ccbcc..", ".cccbccc.", ".ccccccc.", "..ccccc..", "...ccc..."]),
    ("sturdy", {"a": "#6a6a78", "b": "#b0b0c0", "c": "#3a3a48"}, [
        "aaaaaaaaa", "abbbabbba", "abbbabbba", "aaaaaaaaa", "bbabbbabb", "bbabbbabb", "aaaaaaaaa", "abbbabbba", "aaaaaaaaa"]),
    ("fireproof", {"a": "#8a7ac8", "b": "#f0eaff", "c": "#1a1030"}, [
        "....a....", "...aba...", "..abcca..", "..abcca..", ".abcccca.", ".abcccca.", "abcccccca", "aacccccaa", ".aaaaaaa."]),
    ("invisible", {"a": "#b8c0d8", "b": "#ffffff"}, [
        ".........", ".........", "..a.a.a..", ".a.....a.", "a..bbb..a", ".a.....a.", "..a.a.a..", ".........", "........."]),
    ("unconscious", {"a": "#9fc8ff", "b": "#ffffff"}, [
        "aaaaa....", "...a.....", "..a...aaa", ".a.....a.", "aaaaa.a..", "......aaa", ".........", ".........", "........."]),
    ("pursued", {"a": "#8a9a5a", "b": "#d0a060", "c": "#7a5a34", "d": "#c8d890"}, [
        "........d", "..aaa...d", ".abbba..a", "abbcbba.a", "abcbbbaaa", "abbbbbaaa", ".aaaaaaa.", ".........", "........."]),
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
