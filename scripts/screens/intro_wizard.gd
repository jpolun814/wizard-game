class_name IntroWizard
extends Node2D
## One of the ten wizards of the opening scene: a body that stands on the floor, with its sprite as its only child.

var face := 1.0       # the way it looks: 1 to the right, -1 to the left
var alive := true
var here := false     # in its place, and standing
var color := Color.WHITE  # the color of its bolts
var sprite: AnimatedSprite2D
