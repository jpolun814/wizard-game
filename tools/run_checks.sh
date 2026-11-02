#!/bin/sh
# Runs the game's checks side by side and prints one line for each: ok, or FAILED with where its output is. The work is in tools/run_checks.py,
# which says what its options are:  sh tools/run_checks.sh [--all] [--cov] [-j N] [name ...]
exec python "$(dirname "$0")/run_checks.py" "$@"
