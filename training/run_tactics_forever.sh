#!/bin/sh
# Keeps the tactics training going: if the trainer or Godot falls over, it starts again from the last round saved (train_tactics.py carries on
# by itself). Stop it by creating training/tactics/STOP.
cd "$(dirname "$0")"
mkdir -p tactics
while [ ! -f tactics/STOP ]; do
	echo "$(date '+%Y-%m-%d %H:%M:%S') starting trainer" >> tactics/run.log
	python -I -u train_tactics.py --envs "${ENVS:-3}" --port "${PORT:-11040}" --round-steps "${ROUND_STEPS:-20000}" >> tactics/run.log 2>&1
	echo "$(date '+%Y-%m-%d %H:%M:%S') trainer stopped with code $?" >> tactics/run.log
	sleep 15
done
