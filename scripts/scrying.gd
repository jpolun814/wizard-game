class_name Scrying
extends Node

## What the Chant of Scrying leaves: the way to one page, fixed when the chant was said. An arrow at the edge of the screen points to it
## (see EdgeArrows, which looks for everything in the "scryings" group) until the page has been read. To look for another, chant again.

var target: Node2D       # the page being shown
var ledger: Ledger       # the pages the speaker has read


## The nearest page that the ledger lacks, to a point, or null when there is none.
static func nearest_unread(tree: SceneTree, point: Vector2, held: Ledger) -> PagePickup:
	var best: PagePickup = null
	var best_distance := INF
	for page: PagePickup in tree.get_nodes_in_group("pages"):
		if not unread(page, held):
			continue
		var distance := page.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = page
	return best


## True when reading the page would teach the ledger something.
static func unread(page: PagePickup, held: Ledger) -> bool:
	if page.spoils.is_empty():
		return not held.knows(page.page)
	return page.spoils.any(func(each: String) -> bool: return not held.knows(each))


func _ready() -> void:
	add_to_group("scryings")


func _process(_delta: float) -> void:
	if not is_instance_valid(target) or not unread(target as PagePickup, ledger):
		queue_free()
