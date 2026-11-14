extends Node

## A play log is packed, kept by the machine that keeps the game in a folder of its own (not the folder a person's recording is made in), and the
## sender deletes its file once it is told the log is kept.

func _ready() -> void:
	var ok := true
	var raw := "0.00 START\n0.10 S 1 2 3 4 floor 200 200 0 0 idle\n".to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	ok = ok and packed.size() > 2 and packed[0] == 0x1f and packed[1] == 0x8b  # a real gzip file, which any tool can open
	Net._keep_play_log("check_log.log.gz", packed, 7)
	var kept := "%s/peer7_check_log.log.gz" % Net.LOG_DIR
	ok = ok and FileAccess.file_exists(kept)
	ok = ok and Net.LOG_DIR != "user://play_logs"
	if FileAccess.file_exists(kept):
		var back := FileAccess.get_file_as_bytes(kept).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		ok = ok and back == raw
		DirAccess.remove_absolute(kept)
	var local := "user://play_logs/net_check_only.log"
	DirAccess.make_dir_recursive_absolute("user://play_logs")
	var f := FileAccess.open(local, FileAccess.WRITE)
	f.store_line("x")
	f.close()
	Net._logs_sent["check_log.log.gz"] = local
	Net._play_log_kept("check_log.log.gz")  # the other machine says it has it
	ok = ok and not FileAccess.file_exists(local) and not Net._logs_sent.has("check_log.log.gz")
	print("PASS play logs are packed, kept apart and deleted when kept" if ok else "FAIL play log upload")
	get_tree().quit()
