class_name DebugPanel
extends CanvasLayer

## A testing panel, opened and closed with F1. Each button summons one enemy kind on the far side of the screen;
## the last row clears the enemies or fills you back up.

var arena: Node
var panel: PanelContainer


func _ready() -> void:
	layer = 20
	visible = false
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.03, 0.1, 0.88)
	style.border_color = Color(0.6, 0.45, 0.9, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(16, 104)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "Summon (F1 hides this)"
	title.add_theme_font_size_override("font_size", 13)
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	for kind in Mob.KINDS:
		grid.add_child(_button(Mob.KINDS[kind].display_name, _summon.bind(kind)))
	var tools := HBoxContainer.new()
	column.add_child(tools)
	tools.add_child(_button("Clear enemies", func() -> void: arena.clear_enemies()))
	tools.add_child(_button("Refill", _refill))
	tools.add_child(_button("All spells", func() -> void: arena.learn_every_page()))
	if arena.has_method("open_gates"):
		tools.add_child(_button("Rift into locked areas", func() -> void: arena.open_gates()))
	if arena.has_method("gate_kinds"):
		var heading := Label.new()
		heading.text = "Go to a gate (each press, the next one)"
		heading.add_theme_font_size_override("font_size", 13)
		column.add_child(heading)
		var gates := GridContainer.new()
		gates.columns = 3
		gates.add_theme_constant_override("h_separation", 4)
		gates.add_theme_constant_override("v_separation", 4)
		column.add_child(gates)
		for kind: String in arena.gate_kinds():
			gates.add_child(_button(kind.capitalize(), arena.go_to_gate.bind(kind)))


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size = Vector2(104, 0)
	button.focus_mode = Control.FOCUS_NONE  # so Space or Enter cannot fire the same button again
	button.pressed.connect(action)
	return button


func _summon(kind: String) -> void:
	arena.summon_far_side(kind)


func _refill() -> void:
	arena.player.max_stamina = arena.player.MAX_STAMINA
	arena.player.stamina = arena.player.max_stamina
