#!/bin/sh
# Keeps the curriculum training going (train_duel.py): if the trainer or Godot falls over, it starts again from the last round saved. Stop it by
# creating STOP in its folder (OUT, default duel). STAGE picks the stage; FROM, the last stage's network to begin a new one with (used only when
# OUT has no rounds yet); ENVS, LANES and PORT as in train_duel.py.
cd "$(dirname "$0")"
mkdir -p "${OUT:-duel}"
while [ ! -f "${OUT:-duel}/STOP" ]; do
	echo "$(date '+%Y-%m-%d %H:%M:%S') starting trainer" >> "${OUT:-duel}/run.log"
	python -I -u train_duel.py --stage "${STAGE:-1}" --envs "${ENVS:-5}" --lanes "${LANES:-4}" --port "${PORT:-11400}" --out "${OUT:-duel}" ${FROM:+--from "$FROM"} >> "${OUT:-duel}/run.log" 2>&1
	echo "$(date '+%Y-%m-%d %H:%M:%S') trainer stopped with code $?" >> "${OUT:-duel}/run.log"
	sleep 15
done
