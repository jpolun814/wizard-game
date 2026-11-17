class_name IntroWizard
extends Node2D
## One of the ten wizards of the opening scene: a body that stands on the floor, with its sprite as its only child.

var face := 1.0       # the way it looks: 1 to the right, -1 to the left
var alive := true
var lane := 0.0       # the height of the floor it stands on in the crowd (its row)
var climbs := false   # it stands on the stairs where they are under it, and not on the floor in front
var here := false     # in its place, and standing
var color := Color.WHITE  # the color of its bolts
var sprite: AnimatedSprite2D
var magic: MagicLayer  # over the sprite: the glow of its staff (a wizard made of parts has one)
