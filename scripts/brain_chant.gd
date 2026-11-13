class_name BrainChant
extends RefCounted

## The chant box of an AI wizard: it stops, types the words as a person does, and says them. A person with the box open cannot walk, jump or draw (the
## keys type letters), so it does none of them; when something comes at it, it closes the box, as a person would, and the words are lost.

const STOPPING := 0.35  # seconds to come to a stop before the first letter of a chant (a person stops walking, then reaches for the box)
const TYPING_FASTEST := 0.08  # seconds a letter takes to type, from the quick end of the people recorded to the slow
const TYPING_SLOWEST := 0.15  # (1,493 letters: tools/measure_human.py, ai/human_limits.json); a skilled wizard types at the quick end

var typing := ""  # the chant it is typing, and will say when the brain's settle has run out
var age := 0.0  # seconds since the chant box was opened
var total := 1.0  # how long the typing is to take, the stop before it included
var said := {}  # chant id -> whether it took, for a chant just typed and said, until whoever asked for it looks (see type_then_say)
var said_failed := {}  # chant id -> seconds before it is tried again, after it was typed and came to nothing
var breaks := 0  # chants broken off lately: the more, the longer before it tries again, and the farther from the trouble

var brain: WizardBrain
var wizard: Wizard


func _init(owner: WizardBrain, body: Wizard) -> void:
	brain = owner
	wizard = body


## Once a frame: a chant that came to nothing may be tried again after a while.
func tick(delta: float) -> void:
	for id in said_failed.keys():
		said_failed[id] -= delta
		if said_failed[id] <= 0.0:
			said_failed.erase(id)


## How long a person takes to type a chant: it stands where it is while it does.
func typing_time(id: String) -> float:
	return float(RitualInput.RITUALS[id]["text"].length()) * lerpf(TYPING_SLOWEST, TYPING_FASTEST, brain.skill)


## True while the chant box is open and it is typing.
func is_typing() -> bool:
	return typing != ""


## The chant it is typing, as far as it has got, for over its head: a person's words are seen as they are typed, and so are these.
func words_shown() -> String:
	if typing == "" or not RitualInput.RITUALS.has(typing):
		return ""
	var text: String = RitualInput.RITUALS[typing]["text"]
	var done := 1.0 - clampf(brain.settle / maxf(total, 0.01), 0.0, 1.0)
	return text.substr(0, int(ceil(text.length() * done)))


## It opens the chant box: it stops, and types the words.
func open(id: String) -> void:
	typing = id
	age = 0.0
	total = typing_time(id) + STOPPING
	brain.settle = total


## It closes the chant box before the words are done.
func close() -> void:
	typing = ""
	brain.settle = 0.0


## The chant box open: the wizard stands and types. When something comes at it, it closes the box. When the last letter is typed the chant is said:
## the chant's id is returned then (and `said` holds whether it took), and otherwise "".
func while_typing() -> String:
	wizard.walk(0.0)
	age += wizard.get_physics_process_delta_time()
	var foe := brain.foe()
	var threatened := not brain.incoming_shot().is_empty() or (is_instance_valid(foe) and brain.eyes_see(foe) and foe.center().distance_to(wizard.center()) < WizardBrain.TOO_CLOSE)
	if threatened:
		close()
		return ""
	if brain.settle > 0.0:
		return ""
	var id := typing
	typing = ""
	breaks = 0
	said[id] = wizard.chant(id)
	return id


## A chant asked for where it is needed (a gate, a lost rival): it types it first. True once it has been said; false while it is being typed, or
## when the last try at it came to nothing.
func type_then_say(id: String) -> bool:
	if said.has(id):
		var done: bool = said[id]
		said.erase(id)
		if not done:
			said_failed[id] = 3.0
		return done
	if said_failed.get(id, 0.0) > 0.0 or not RitualInput.RITUALS.has(id):
		return false
	if typing == "" and wizard.is_on_floor() and not wizard.is_drawing():
		open(id)
	return false
