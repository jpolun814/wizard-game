class_name DebugPanel
extends CanvasLayer

## A debugging panel, opened and closed with F1. Each button summons one enemy kind on the far side of the screen.

var arena: Node
var panel: PanelContainer


func _ready() -> void:
	layer = 20
	visible = false
	panel = PanelContainer.new()
	panel.position = Vector2(16, 120)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "Summon enemy (F1 hides this)"
	column.add_child(title)
	for kind in Mob.KINDS:
		var button := Button.new()
		button.text = Mob.KINDS[kind]["name"]
		button.focus_mode = Control.FOCUS_NONE  # so Space or Enter cannot fire the same button again
		button.pressed.connect(_summon.bind(kind))
		column.add_child(button)


func _summon(kind: String) -> void:
	arena.summon_far_side(kind)
