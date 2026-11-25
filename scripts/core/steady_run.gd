class_name SteadyRun
extends Node

## A run that comes out the same every time. The tests' runner asks for one by naming a seed in the environment (WIZARD_SEED); a game a person
## plays never has it, and then nothing here does anything.
##
## In a steady run the dice start from that seed (this is the first autoload, so nothing has thrown them yet), and what would otherwise follow the
## real clock or another core of the machine follows the game's own time instead: how long a sound lasts (Sfx) and what is loaded ahead (Warmup).
## Run with --fixed-fps, every frame is then the same length and the whole game is worked out from the seed alone, however busy the machine is.
##
## A network check is several copies of the game. WIZARD_HUB says where they meet at the end of every frame: each sends what it has to say to the others
## and waits until all have, so every copy is always at the same frame (see the Hub in tools/steady.py, and SteadyPeer, the line made of it).
##
## WIZARD_TRACE names a file to write what the world looked like at every tenth physics frame to (WIZARD_TRACE_EVERY: or every so many), so that two runs can be compared line by line
## (`python tools/run_checks.py --twice` does it): the first line that differs is the moment they parted.

static var on := OS.get_environment("WIZARD_SEED") != ""

static var every := 10

static var copy := 0      # which copy of the game this is, in a network check
static var calls := 0     # how many times this copy has joined a game
static var lines: Array = []   # the lines that are open (SteadyPeer)
static var _out: Array = []    # what is to be said at the end of this frame: [to which copy (-1 for all), what]

var _trace: FileAccess
var _throw := 0
var _hub: StreamPeerTCP
var _here: Array = []     # the copies that were there at the last frame


static func networked() -> bool:
	return on and OS.get_environment("WIZARD_HUB") != ""


static func say(to: int, what: Array) -> void:
	if networked():  # (a copy that is alone has nobody to say it to)
		_out.append([to, what])


func _init() -> void:
	if not on:
		return
	seed(OS.get_environment("WIZARD_SEED").to_int())
	var path := OS.get_environment("WIZARD_TRACE")
	if path != "":
		_trace = FileAccess.open(path, FileAccess.WRITE)
		if OS.get_environment("WIZARD_TRACE_EVERY") != "":
			every = OS.get_environment("WIZARD_TRACE_EVERY").to_int()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000000  # the end of the frame: everything else has had its turn
	set_physics_process(on)
	set_process(networked())
	if networked():
		_meet()


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % 10 == 0:
		_throw = randi()  # (it shows when the dice of two runs have parted, before anything seen has; thrown whether or not there is a trace, so that a trace does not change the game)
	if _trace == null or Engine.get_physics_frames() % every != 0:
		return
	var line := "%d nodes %d dice %d" % [Engine.get_physics_frames(), get_tree().get_node_count(), _throw]
	for group in [&"wizards", &"mobs", &"shots"]:
		for body: Node in get_tree().get_nodes_in_group(group):
			if body is Node2D:
				line += " %s(%.3f,%.3f" % [group, body.global_position.x, body.global_position.y]
				line += ",%.3f,%.3f)" % [body.stamina, body.max_stamina] if body is Wizard else ")"
	_trace.store_line(line)
	_trace.flush()


func _meet() -> void:
	copy = OS.get_environment("WIZARD_COPY").to_int()
	_hub = StreamPeerTCP.new()
	_hub.connect_to_host("127.0.0.1", OS.get_environment("WIZARD_HUB").to_int())
	while _hub.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		_hub.poll()
		OS.delay_msec(1)
	_hub.set_no_delay(true)
	_hub.put_u32(copy)


## The end of a frame: what this copy has to say goes out, and what all of them said comes in.
func _process(_delta: float) -> void:
	var packed := var_to_bytes(_out)
	_out = []
	_hub.put_u32(packed.size())
	_hub.put_data(packed)
	var size := _hub.get_u32()
	if size == 0:
		get_tree().quit(1)  # the runner has gone
		return
	var said: PackedByteArray = _hub.get_data(size)[1]
	var here: Array = []
	var at := 0
	while at < said.size():
		var from := said.decode_u32(at)
		var length := said.decode_u32(at + 4)
		here.append(from)
		if from != copy:
			for each: Array in bytes_to_var(said.slice(at + 8, at + 8 + length)):
				if each[0] == -1 or each[0] == copy:
					for line: RefCounted in lines.duplicate():
						line.hear(from, each[1])
		at += 8 + length
	for gone: int in _here:
		if not here.has(gone):
			for line: RefCounted in lines.duplicate():
				line.copy_gone(gone)
	_here = here
