extends Node2D

## A shot that is no spell: what a Barrier must turn away (see Elements.shield_turns).

var turned := false


func _ready() -> void:
	add_to_group("shots")


func deflected() -> void:
	turned = true
