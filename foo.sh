#!/usr/bin/env bash

export HOST="livessh"

HWADDR="$(cat /sys/class/net/*/address | egrep '^[0-9a-f][048c](:[0-9a-f]{2}){5}$' | egrep -v '^00(:00){5}$' | sort -u | head -n 1)"

if [ "x${HWADDR}" != "x" ]; then
#    export HOST="${HOST}-$(echo $HWADDR | cut -d : -f 4)-$(echo $HWADDR | cut -d : -f 5)-$(echo $HWADDR | cut -d : -f 6)"
    export HOST="${HOST}-$(echo $HWADDR | sed 's/://g')"
fi

echo $HOST
