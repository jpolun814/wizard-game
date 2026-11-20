extends GdUnitTestSuite
## The music (Music, scripts/core/music.gd): every place it names is a real one, every track it names is a file that loads and loops, and moving from
## place to place plays the right track, keeps a shared one going rather than starting it again, and goes quiet where there is none.

const PLACES := ["menu", "waiting_room"]  # the places that are not biomes


func before_test() -> void:
	Music.in_the_game = true  # (it is off in the game while the music is not ready)


func after_test() -> void:
	Music.play_for("")
	Music.in_the_game = false


func test_every_place_is_real() -> void:
	for where: String in Music.TRACKS:
		assert_bool(PLACES.has(where) or SurfaceGen.BIOMES.has(where)).override_failure_message("Music.TRACKS names a place that does not exist: " + where).is_true()


func test_every_track_loads_and_loops() -> void:
	for where: String in Music.TRACKS:
		var file: String = Music.TRACKS[where]["file"]
		var stream := load("res://music/%s.ogg" % file) as AudioStreamOggVorbis
		assert_object(stream).override_failure_message("missing or not Ogg Vorbis: music/%s.ogg" % file).is_not_null()
		assert_float(stream.get_length()).is_greater(5.0)
	Music.play_for("menu")
	assert_bool((Music.get_child(Music.get_child_count() - 1) as AudioStreamPlayer).stream.loop).is_true()


func test_each_place_plays_its_track() -> void:
	Music.play_for("menu")
	assert_str(Music.playing()).is_equal(Music.TRACKS["menu"]["file"])
	Music.play_for("waiting_room")
	assert_str(Music.playing()).is_equal(Music.TRACKS["waiting_room"]["file"])
	var room := Music.playing()
	var players := Music.get_child_count()
	Music.play_for("portals")  # the same track: it goes on, no second player is started
	assert_str(Music.playing()).is_equal(room)
	assert_int(Music.get_child_count()).is_equal(players)
	Music.play_for("no such place")  # no track there
	assert_str(Music.playing()).is_equal("")
