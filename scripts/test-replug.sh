#!/bin/sh
# Run on the RV1106 board while replugging joysticks.
# Prints joystick by-path transitions with a monotonic timestamp.
#
# Usage: joy_replug_test.sh [seconds]   (default 120)

DUR="${1:-120}"
END=$(( $(date +%s) + DUR ))
prev=""

echo "joy-replug-test: watching for ${DUR}s; replug sticks now"
while [ "$(date +%s)" -lt "$END" ]; do
    now="$(cut -d' ' -f1 /proc/uptime)"
    names="$(ls /dev/input/by-path/*-event-joystick 2>/dev/null | sed 's#.*/##' | tr '\n' ' ')"
    count="$(ls /dev/input/by-path/*-event-joystick 2>/dev/null | wc -l)"
    state="count=${count} names=${names}"
    if [ "$state" != "$prev" ]; then
        echo "t=${now} ${state}"
        prev="$state"
    fi
    sleep 0.2
done
echo "joy-replug-test: done"
