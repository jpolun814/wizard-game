class_name WorldStages
extends RefCounted

## A world gives way to the next: the portal in the sky grows unstable, warns, pulls everyone toward it and gives way, and the match goes on in a world
## that is smaller. The clock is the host's in a network game.

var tear: Node2D  # the portal giving way, while it does
var pulling := false

var world: World

var _in := -1.0  # seconds until the portal gives way, once it has begun to


func _init(owner: World) -> void:
	world = owner


## Counts down to the collapse of the portal: the warning, the shaking, and then the new world.
func watch(delta: float) -> void:
	var seconds: float = MatchState.plan()["seconds"] * MatchState.hurry
	if seconds <= 0.0 or (world.player.dead and not world.match_end.spectating and not Net.dedicated):  # (a server's own wizard may fall, and the clock goes on for the people on other machines)
		return
	world.stage_time += delta
	if _in < 0.0 and world.stage_time >= seconds - MatchState.WARNING and Net.is_host():  # in a network game the host's clock is the one that counts
		begin()
		Net.send(world, &"_begin_collapse")
	if _in < 0.0:
		return
	_in -= delta
	GameCamera.shake_scene(world.get_tree(), 0.03 + 0.06 * (1.0 - _in / MatchState.WARNING))
	if not pulling and _in <= World.PortalCollapse.PULL:
		pulling = true
		tear.pull(SpellTargets.wizards(world.get_tree()))  # everyone still standing
	if _in <= 0.0 and not world.leaving:
		collapse()



## The warning: the portal is growing unstable, and gives way in a little while.
func begin() -> void:
	if _in >= 0.0:
		return
	_in = MatchState.WARNING
	world.hud.banner("The portal is growing unstable")
	Sfx.play("thunder", world.player.center(), -4.0)
	tear = World.PortalCollapse.new()
	tear.position = Vector2(ArenaGen.world_size.x * World.TILE * 0.5, 8.0 * World.TILE)  # high in the middle of the world
	world.add_child(tear)


## The portal gives way: everyone who is left is thrown into the next world, smaller than this one.
## For the F1 panel: leaves for a world of the match now, as the collapse would (the one stood in too: it is built again).
func go_to_stage(at: int) -> void:
	if world.leaving:
		return
	MatchState.stage = at - 1  # the collapse moves on to the next
	collapse()


## For the F1 panel: leaves for a world of any biome now, whether or not this match's seed would deal it, keeping this world's place in the match.
func go_to_biome(biome: String) -> void:
	if world.leaving:
		return
	go_to_stage(MatchState.stage)
	MatchState.forced_biome = biome


func collapse() -> void:
	world.leaving = true
	var state: Array[Dictionary] = []
	for wizard in world.seats:
		if is_instance_valid(wizard):
			wizard.end_wild()  # the wolf does not travel: the wizard's own stamina is what is carried on
		if wizard == world.player:
			state.append({"alive": not world.player.dead, "max": world.player.max_stamina, "stamina": world.player.stamina})
		elif is_instance_valid(wizard) and not wizard.dead:
			state.append({"alive": true, "max": wizard.max_stamina, "stamina": wizard.stamina})
		else:
			state.append({"alive": false})
	World.next_seed = MatchState.advance(world.ledgers, state, Incantation.seed_count())
	world.leave_network_scene()
	Sfx.play("portal_enter", world.player.center(), -2.0)
	world.fade_to_black(0.7, func() -> void:
		Loading.quiet = true
		world.get_tree().change_scene_to_file(Loading.SCREEN))
