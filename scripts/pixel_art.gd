class_name PixelArt

## Made by tools/prepare_gothic_art.py. Do not edit by hand: run the tool again instead.
## CHARACTERS: each one's frame size in pixels, and the box around its body measured from its anchor (the
## bottom middle of the frame for walkers, the middle for flyers). FX: each effect strip's frame size and count.

const CHARACTERS := {
	"skeleton": {"size": Vector2(146, 59), "body": Rect2(-14.9, -51.0, 27.0, 51.0), "flyer": false},
	"goblin": {"size": Vector2(72, 41), "body": Rect2(-10.4, -36.0, 21.0, 36.0), "flyer": false},
	"eye": {"size": Vector2(60, 52), "body": Rect2(-18.7, -15.5, 27.0, 31.0), "flyer": true},
	"giant": {"size": Vector2(48, 42), "body": Rect2(-8.3, -38.0, 18.0, 38.0), "flyer": false},
	"ninja": {"size": Vector2(168, 67), "body": Rect2(-5.4, -56.0, 13.0, 56.0), "flyer": false},
	"wizard": {"size": Vector2(254, 138), "body": Rect2(-20.9, -86.0, 37.0, 86.0), "flyer": false},
	"dark_wizard": {"size": Vector2(238, 143), "body": Rect2(-13.7, -95.0, 42.0, 95.0), "flyer": false},
	"pyre_wizard": {"size": Vector2(134, 71), "body": Rect2(-11.1, -57.0, 21.0, 55.0), "flyer": false},
	"bone_wizard": {"size": Vector2(140, 68), "body": Rect2(-9.0, -53.0, 15.0, 53.0), "flyer": false},
}

const FX := {
	"ninja_star": {"size": Vector2(32, 32), "frames": 1},
	"fireball": {"size": Vector2(64, 32), "frames": 9},
	"icespear": {"size": Vector2(64, 32), "frames": 6},
	"lightning": {"size": Vector2(100, 200), "frames": 7},
	"blast_small": {"size": Vector2(64, 64), "frames": 8},
	"blast_fire": {"size": Vector2(80, 80), "frames": 16},
	"blast_ring": {"size": Vector2(32, 32), "frames": 8},
	"dark_orb": {"size": Vector2(16, 16), "frames": 6},
	"magic_bolt": {"size": Vector2(16, 16), "frames": 6},
	"shield": {"size": Vector2(48, 48), "frames": 6},
	"wind_bolt": {"size": Vector2(16, 16), "frames": 6},
	"tornado": {"size": Vector2(96, 96), "frames": 60},
	"rock": {"size": Vector2(16, 16), "frames": 1},
	"fire_puff": {"size": Vector2(24, 62), "frames": 7},
	"fire_band": {"size": Vector2(96, 54), "frames": 6},
	"fire_wall": {"size": Vector2(42, 77), "frames": 7},
	"flame": {"size": Vector2(64, 64), "frames": 60},
	"vortex": {"size": Vector2(100, 100), "frames": 61},
	"ring": {"size": Vector2(100, 100), "frames": 30},
	"ice_burst": {"size": Vector2(100, 100), "frames": 61},
	"freeze": {"size": Vector2(100, 100), "frames": 86},
	"bubbles": {"size": Vector2(100, 100), "frames": 61},
	"portal_purple": {"size": Vector2(64, 64), "frames": 24},
	"splash": {"size": Vector2(32, 32), "frames": 6},
}
