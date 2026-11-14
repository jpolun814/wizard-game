class_name DebugPanel
extends CanvasLayer

## A testing panel, opened and closed with F1. Each button summons one enemy kind on the far side of the screen;
## the last row clears the enemies or fills you back up.

var arena: Arena
var panel: PanelContainer
var _world_buttons: Array[Button] = []


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
	var world := arena as World  # only a match has gates, worlds and an ending
	if world == null:
		return
	tools.add_child(_button("Rift into locked areas", func() -> void: world.open_gates()))
	tools.add_child(_button("The ending", func() -> void: world.go_to_epilogue()))
	tools.add_child(_button("Win game", func() -> void: _end_the_match(true)))  # the match ends: every other wizard falls, or the person does
	tools.add_child(_button("Lose game", func() -> void: _end_the_match(false)))
	var gates_heading := Label.new()
	gates_heading.text = "Go to a gate (each press, the next one)"
	gates_heading.add_theme_font_size_override("font_size", 13)
	column.add_child(gates_heading)
	var gates := GridContainer.new()
	gates.columns = 3
	gates.add_theme_constant_override("h_separation", 4)
	gates.add_theme_constant_override("v_separation", 4)
	column.add_child(gates)
	for kind: String in world.gate_kinds():
		gates.add_child(_button(kind.capitalize(), world.go_to_gate.bind(kind)))
	if not Net.online():  # in a network game the host's clock moves everyone together
		var heading := Label.new()
		heading.text = "Go to a world of the match"
		heading.add_theme_font_size_override("font_size", 13)
		column.add_child(heading)
		var worlds := GridContainer.new()
		worlds.columns = 2
		worlds.add_theme_constant_override("h_separation", 4)
		worlds.add_theme_constant_override("v_separation", 4)
		column.add_child(worlds)
		for stage in MatchState.STAGES.size():
			var button := _button("", world.go_to_stage.bind(stage))
			button.custom_minimum_size = Vector2(160, 0)
			worlds.add_child(button)
			_world_buttons.append(button)
		visibility_changed.connect(_name_worlds)
		_name_worlds()
		var any := Label.new()
		any.text = "Go to any biome"
		any.add_theme_font_size_override("font_size", 13)
		column.add_child(any)
		var biomes := GridContainer.new()
		biomes.columns = 2
		biomes.add_theme_constant_override("h_separation", 4)
		biomes.add_theme_constant_override("v_separation", 4)
		column.add_child(biomes)
		for biome: String in SurfaceGen.BIOMES:
			var button := _button(SurfaceGen.LOOKS[biome]["title"], world.go_to_biome.bind(biome))
			button.custom_minimum_size = Vector2(160, 0)
			biomes.add_child(button)


## Puts the panel away and ends the match for real: the person wins (every other wizard is beaten) or loses (they are), and what follows is what the game does.
func _end_the_match(won: bool) -> void:
	visible = false
	var world := arena as World
	if won:
		world.debug_win()
	else:
		world.debug_lose()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size = Vector2(104, 0)
	button.focus_mode = Control.FOCUS_NONE  # so Space or Enter cannot fire the same button again
	button.pressed.connect(action)
	return button


## The buttons that go to a world say which it is: its number and its biome, which the match's seed decides.
func _name_worlds() -> void:
	for stage in _world_buttons.size():
		_world_buttons[stage].text = "%d: %s" % [stage + 1, SurfaceGen.LOOKS[MatchState.biome_of(stage)]["title"]]


func _summon(kind: String) -> void:
	arena.summon_far_side(kind)


func _refill() -> void:
	arena.player.max_stamina = arena.player.MAX_STAMINA
	arena.player.stamina = arena.player.max_stamina
