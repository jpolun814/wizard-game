#!/bin/sh
# The night of 2026-11-10: wait for the evaluation of round 556 to finish, train in duels for five hours, then evaluate the latest duel round.
cd "$(dirname "$0")"
LOG=tactics_duel_night.log
echo "$(date '+%F %T') waiting for the round 556 evaluation" >> $LOG
while tasklist | grep -qi "python"; do sleep 60; done
echo "$(date '+%F %T') evaluation done: $(tail -1 tactics/eval_556.txt)" >> $LOG
mkdir -p tactics_duel
rm -f tactics_duel/STOP
OUT=tactics_duel EXTRA=--duel ENVS=3 PORT=11070 ./run_tactics_forever.sh &
sleep 18000
touch tactics_duel/STOP
sleep 5
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { \$_.CommandLine -match 'train_tactics|tactics_env' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }"
sleep 10
last=$(ls tactics_duel/round_*.json | sed 's/.*round_\([0-9]*\).json/\1/' | sort -n | tail -1)
echo "$(date '+%F %T') duel training stopped at round $last; evaluating it" >> $LOG
cd ..
python -I -u training/eval_tactics.py res://training/tactics_duel/round_$last.json --seeds 100 --jobs 5 > training/tactics_duel/eval_$last.txt 2>&1
echo "$(date '+%F %T') duel evaluation done: $(tail -1 training/tactics_duel/eval_$last.txt)" >> training/$LOG
