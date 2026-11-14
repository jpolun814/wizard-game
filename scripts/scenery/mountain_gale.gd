class_name MountainGale
extends Node

## The wind of the snowy peaks: calm at the foot of the mountains and stronger the higher a wizard climbs, gusting one way and then the
## other. It leans on every wizard this machine plays (the others are moved by the machines that play them).

const WIND := 110.0        # the push at the very top, in pixels a second
const CALM_ROWS := 8.0     # rows above the plains where the wind is still nothing
const FULL_ROWS := 36.0    # and where it blows its hardest
const GUST := 0.27         # how quickly it changes its mind

var seconds := 0.0  # how long it has blown


## How hard the wind blows at a height, from 0 to 1.
static func altitude(y: float) -> float:
	var rows := float(SurfaceGen.BASE_ROW) - y / float(ArenaGen.TILE)
	return clampf((rows - CALM_ROWS) / (FULL_ROWS - CALM_ROWS), 0.0, 1.0)


## The push of the wind at a height, a moment into the world, to the right when it is above nothing.
static func push_at(y: float, seconds: float) -> float:
	return altitude(y) * WIND * sin(seconds * GUST)


func _physics_process(delta: float) -> void:
	seconds += delta
	for wizard: Wizard in get_tree().get_nodes_in_group("wizards"):
		if SpellTargets.affects(wizard) and not wizard.is_likeness():
			wizard.wind = push_at(wizard.global_position.y, seconds)
