#!/bin/sh
# Keeps the tactics training going: if the trainer or Godot falls over, it starts again from the last round saved (train_tactics.py carries on
# by itself). Stop it by creating STOP in its folder (OUT, default training/tactics). EXTRA passes more arguments (EXTRA=--duel).
cd "$(dirname "$0")"
mkdir -p "${OUT:-tactics}"
while [ ! -f "${OUT:-tactics}/STOP" ]; do
	echo "$(date '+%Y-%m-%d %H:%M:%S') starting trainer" >> "${OUT:-tactics}/run.log"
	python -I -u train_tactics.py --envs "${ENVS:-3}" --port "${PORT:-11040}" --round-steps "${ROUND_STEPS:-20000}" --out "${OUT:-tactics}" ${EXTRA} >> "${OUT:-tactics}/run.log" 2>&1
	echo "$(date '+%Y-%m-%d %H:%M:%S') trainer stopped with code $?" >> "${OUT:-tactics}/run.log"
	sleep 15
done
