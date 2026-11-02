#!/bin/sh
# Runs the game's quick checks one after another and prints one line for each: ok, or FAILED with the exit code. It is for after a change that could
# break something far from where it was made. The long ones (a whole match, two machines over a network, pictures that need a window) are not in it.
#     sh tools/run_checks.sh            (from the game's folder)
GODOT="${GODOT:-/c/Users/Jordan Polun/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
failed=0
scene() {
	timeout 900 "$GODOT" --headless --fixed-fps 60 --path . "tests/$1.tscn" -- $2 > "${TMPDIR:-/tmp}/check_$1.txt" 2>&1
	code=$?
	if [ $code -eq 0 ]; then echo "ok      $1"; else echo "FAILED  $1 (exit $code; see ${TMPDIR:-/tmp}/check_$1.txt)"; failed=$((failed + 1)); fi
}
script() {
	timeout 900 "$GODOT" --headless -s "tests/$1.gd" -- $2 > "${TMPDIR:-/tmp}/check_$1.txt" 2>&1
	grep -q "FAILED" "${TMPDIR:-/tmp}/check_$1.txt" && code=1 || code=0
	if [ $code -eq 0 ]; then echo "ok      $1"; else echo "FAILED  $1 (see ${TMPDIR:-/tmp}/check_$1.txt)"; failed=$((failed + 1)); fi
}
script test_gestures
script test_pages
script test_nav "seeds=6"
script test_stages "seeds=4"
for name in flow_check tutorial_check menu_check stairs_check stairwell_check castle_spells_check castle_sinkhole_fall_check biome_jump_check sinkhole_check sinkhole_biomes_check ridge_check stalagmite_check parity_check interaction_check route_check; do
	scene $name
done
echo "$failed failed"
exit $failed
